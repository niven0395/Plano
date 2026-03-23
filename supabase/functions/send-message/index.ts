import {
  ensureMethod,
  errorResponse,
  jsonResponse,
  optionsResponse,
  parseJSON,
  HTTPError,
} from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";
import { runMessagingRPC, sendPushNotification } from "../_shared/messaging.ts";

interface SendMessagePayload {
  conversation_id: string;
  body: string;
  kind?: string;
  client_id?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(req, "POST");

    const { serviceClient, user } = await requireUser(req);
    const { conversation_id, body, kind, client_id } =
      await parseJSON<SendMessagePayload>(req);

    if (!conversation_id || !body) {
      throw new HTTPError(400, "conversation_id and body are required.");
    }

    const message = await runMessagingRPC<Record<string, unknown>>(
      serviceClient,
      "send_message_server",
      {
        p_conversation_id: conversation_id,
        p_sender_id: user.id,
        p_body: body,
        p_kind: kind ?? "text",
        p_client_id: client_id ?? null,
      },
    );

    const senderRole = message.sender_role as string;
    await sendPushNotification(serviceClient, conversation_id, senderRole, body);

    return jsonResponse(message);
  } catch (err) {
    return errorResponse(err);
  }
});
