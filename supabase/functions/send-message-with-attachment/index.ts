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

interface Attachment {
  storage_path: string;
  file_name: string;
  mime_type: string;
  file_size_bytes: number;
  width?: number;
  height?: number;
}

interface SendMessageWithAttachmentPayload {
  conversation_id: string;
  body: string;
  kind?: string;
  client_id?: string;
  attachment?: Attachment;
  attachments?: Attachment[];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(req, "POST");

    const { serviceClient, user } = await requireUser(req);
    const { conversation_id, body, kind, client_id, attachment, attachments } =
      await parseJSON<SendMessageWithAttachmentPayload>(req);
    const normalizedAttachments = attachments ?? (attachment ? [attachment] : []);

    if (!conversation_id || !body || normalizedAttachments.length === 0) {
      throw new HTTPError(
        400,
        "conversation_id, body, and at least one attachment are required."
      );
    }

    for (const currentAttachment of normalizedAttachments) {
      if (
        !currentAttachment.storage_path ||
        !currentAttachment.file_name ||
        !currentAttachment.mime_type ||
        !currentAttachment.file_size_bytes
      ) {
        throw new HTTPError(
          400,
          "attachments must include storage_path, file_name, mime_type, and file_size_bytes."
        );
      }
    }

    const result = await runMessagingRPC<Record<string, unknown>>(
      serviceClient,
      "send_message_with_attachments_server",
      {
        p_conversation_id: conversation_id,
        p_sender_id: user.id,
        p_body: body,
        p_kind: kind ?? "attachment",
        p_client_id: client_id ?? null,
        p_attachments: normalizedAttachments,
      },
    );

    const message = result.message as Record<string, unknown> | undefined;
    const senderRole = (message?.sender_role ?? result.sender_role) as string;
    await sendPushNotification(serviceClient, conversation_id, senderRole, body);

    return jsonResponse(result);
  } catch (err) {
    return errorResponse(err);
  }
});
