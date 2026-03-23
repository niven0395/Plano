import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { HTTPError } from "./http.ts";

export async function runMessagingRPC<T>(
  serviceClient: SupabaseClient,
  functionName: string,
  params: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await serviceClient.rpc(functionName, params);
  if (error) {
    throw mapMessagingError(error.message);
  }

  return data as T;
}

function mapMessagingError(message: string): HTTPError {
  const normalized = message.toLowerCase();

  if (normalized.includes("rate limit")) {
    return new HTTPError(429, message);
  }

  if (normalized.includes("not found")) {
    return new HTTPError(404, message);
  }

  if (
    normalized.includes("only") ||
    normalized.includes("participant") ||
    normalized.includes("not authorized")
  ) {
    return new HTTPError(403, message);
  }

  if (normalized.includes("already") || normalized.includes("duplicate")) {
    return new HTTPError(409, message);
  }

  return new HTTPError(400, message);
}

export async function sendPushNotification(
  serviceClient: SupabaseClient,
  conversation_id: string,
  sender_role: string,
  message_body: string,
): Promise<{ sent: boolean; token_count: number }> {
  // Look up the conversation to find recipient and sender display name
  const { data: conversation, error: convError } = await serviceClient
    .from("conversations")
    .select("host_id, vendor_id, host_display_name, vendor_display_name")
    .eq("id", conversation_id)
    .single();

  if (convError || !conversation) {
    console.error("Push notification: conversation not found", conversation_id);
    return { sent: false, token_count: 0 };
  }

  // Determine recipient (opposite of sender_role) and sender display name
  const recipientId =
    sender_role === "host" ? conversation.vendor_id : conversation.host_id;
  const senderDisplayName =
    sender_role === "host"
      ? conversation.host_display_name
      : conversation.vendor_display_name;

  // Enqueue the push notification job to the pgmq queue for async processing
  const jobPayload = {
    conversation_id,
    sender_role,
    message_body,
    recipient_id: recipientId,
    sender_display_name: senderDisplayName,
  };

  const { data: msgId, error: enqueueError } = await serviceClient.rpc(
    "pgmq_send",
    {
      queue_name: "push_notification_jobs",
      msg: jobPayload,
    },
  );

  if (enqueueError) {
    console.error(
      "Push notification: failed to enqueue job",
      enqueueError.message,
    );
    return { sent: false, token_count: 0 };
  }

  console.log(
    `Push notification job enqueued: msg_id=${msgId}, recipient=${recipientId}`,
  );

  // Return sent: true to indicate the job was accepted.
  // token_count is 0 here because actual token lookup happens during queue processing.
  return { sent: true, token_count: 0 };
}
