import { createServiceClient } from "../_shared/supabase.ts";
import {
  errorResponse,
  jsonResponse,
  optionsResponse,
} from "../_shared/http.ts";
import { deliverAPNsNotifications } from "../_shared/apns.ts";

/**
 * Process Push Queue
 *
 * Reads messages from the `push_notification_jobs` pgmq queue, processes each
 * push notification job (fetches device tokens and delivers via APNs when configured),
 * and archives processed messages.
 *
 * Intended to be invoked via cron (pg_cron / Supabase cron) or webhook trigger.
 * Accepts POST requests. No auth required when called from cron; add auth
 * middleware if exposed externally.
 */

interface PushNotificationJob {
  conversation_id: string;
  sender_role: string;
  message_body: string;
  recipient_id: string;
  sender_display_name: string;
}

interface QueueMessage {
  msg_id: number;
  read_ct: number;
  enqueued_at: string;
  vt: string;
  message: PushNotificationJob;
}

const QUEUE_NAME = "push_notification_jobs";
const VISIBILITY_TIMEOUT = 30; // seconds
const BATCH_SIZE = 10;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const serviceClient = createServiceClient();

    // Read a batch of messages from the queue
    const { data: messages, error: readError } = await serviceClient.rpc(
      "pgmq_read",
      {
        queue_name: QUEUE_NAME,
        vt: VISIBILITY_TIMEOUT,
        qty: BATCH_SIZE,
      },
    );

    if (readError) {
      console.error("Failed to read from push queue:", readError.message);
      return jsonResponse(
        { error: "Failed to read from queue", detail: readError.message },
        500,
      );
    }

    if (!messages || messages.length === 0) {
      return jsonResponse({ processed: 0, message: "Queue empty" });
    }

    let processed = 0;
    let failed = 0;

    for (const msg of messages as QueueMessage[]) {
      try {
        const job = msg.message;

        // Fetch device tokens for the recipient
        const { data: tokens, error: tokenError } = await serviceClient
          .from("device_tokens")
          .select("token, platform")
          .eq("user_id", job.recipient_id);

        if (tokenError) {
          console.error(
            `Push job ${msg.msg_id}: failed to fetch tokens for ${job.recipient_id}`,
            tokenError.message,
          );
          // Archive anyway to avoid infinite retry on permanent failures
          await archiveMessage(serviceClient, msg.msg_id);
          failed++;
          continue;
        }

        if (!tokens || tokens.length === 0) {
          console.log(
            `Push job ${msg.msg_id}: no device tokens for recipient ${job.recipient_id}, skipping`,
          );
          await archiveMessage(serviceClient, msg.msg_id);
          processed++;
          continue;
        }

        // Truncate body for notification display
        const truncatedBody =
          job.message_body.length > 200
            ? job.message_body.substring(0, 197) + "..."
            : job.message_body;

        // Prepare the APNs payload
        const apnsResult = await deliverAPNsNotifications({
          title: job.sender_display_name,
          body: truncatedBody,
          data: {
            conversation_id: job.conversation_id,
            sender_role: job.sender_role,
            type: "new_message",
          },
          tokens: tokens.map((t: { token: string }) => t.token),
        });

        if (apnsResult.invalidTokens.length > 0) {
          await removeInvalidTokens(serviceClient, apnsResult.invalidTokens);
        }

        if (apnsResult.skipped) {
          console.log(
            `Push job ${msg.msg_id}: skipped APNs delivery (${apnsResult.reason ?? "unknown"})`,
          );
        } else {
          console.log(
            `Push job ${msg.msg_id}: delivered=${apnsResult.delivered}, failed=${apnsResult.failed}`,
          );
        }

        // Archive the processed message
        await archiveMessage(serviceClient, msg.msg_id);
        processed++;
      } catch (jobError) {
        console.error(`Push job ${msg.msg_id}: unexpected error`, jobError);
        failed++;
        // Do not archive on unexpected errors — the message will become visible
        // again after the visibility timeout for retry.
      }
    }

    return jsonResponse({ processed, failed, total: messages.length });
  } catch (err) {
    return errorResponse(err);
  }
});

async function archiveMessage(
  serviceClient: ReturnType<typeof createServiceClient>,
  msgId: number,
): Promise<void> {
  const { error } = await serviceClient.rpc("pgmq_archive", {
    queue_name: QUEUE_NAME,
    msg_id: msgId,
  });

  if (error) {
    console.error(`Failed to archive message ${msgId}:`, error.message);
  }
}

async function removeInvalidTokens(
  serviceClient: ReturnType<typeof createServiceClient>,
  tokens: string[],
): Promise<void> {
  const { error } = await serviceClient
    .from("device_tokens")
    .delete()
    .in("token", tokens);

  if (error) {
    console.error("Failed to remove invalid device tokens:", error.message);
  }
}
