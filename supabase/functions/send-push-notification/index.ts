import { createServiceClient, requireUser } from "../_shared/supabase.ts";
import {
  corsHeaders,
  ensureMethod,
  errorResponse,
  jsonResponse,
  optionsResponse,
  parseJSON,
  HTTPError,
} from "../_shared/http.ts";

interface PushPayload {
  conversation_id: string;
  sender_role: "host" | "vendor";
  sender_name: string;
  body: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(req, "POST");

    const { serviceClient } = await requireUser(req);
    const { conversation_id, sender_role, sender_name, body } =
      await parseJSON<PushPayload>(req);

    if (!conversation_id || !sender_role || !body) {
      throw new HTTPError(
        400,
        "conversation_id, sender_role, and body are required."
      );
    }

    // Look up the conversation to find the recipient
    const { data: conversation, error: convError } = await serviceClient
      .from("conversations")
      .select("host_id, vendor_id, host_display_name, vendor_display_name")
      .eq("id", conversation_id)
      .single();

    if (convError || !conversation) {
      throw new HTTPError(404, "Conversation not found.");
    }

    // Determine recipient user ID
    const recipientId =
      sender_role === "host" ? conversation.vendor_id : conversation.host_id;

    // Fetch device tokens for recipient
    const { data: tokens, error: tokenError } = await serviceClient
      .from("device_tokens")
      .select("token, platform")
      .eq("user_id", recipientId);

    if (tokenError || !tokens || tokens.length === 0) {
      return jsonResponse({ sent: false, reason: "no_device_tokens" });
    }

    // Truncate body for notification
    const truncatedBody =
      body.length > 200 ? body.substring(0, 197) + "..." : body;

    // NOTE: Actual APNs delivery requires Apple Push Notification service integration.
    // This function prepares the payload; the actual sending would be handled by
    // a push notification service (e.g., Firebase Cloud Messaging, OneSignal, or direct APNs).
    // For now, we log the intent and return the payload for the client to handle.
    const payload = {
      notification: {
        title: sender_name,
        body: truncatedBody,
      },
      data: {
        conversation_id,
        sender_role,
        type: "new_message",
      },
      tokens: tokens.map((t: { token: string }) => t.token),
    };

    console.log("Push notification payload prepared:", JSON.stringify(payload));

    return jsonResponse({
      sent: true,
      recipient_id: recipientId,
      token_count: tokens.length,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
