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

interface MarkReadPayload {
  conversation_id: string;
  role: "host" | "vendor";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(req, "POST");

    const { serviceClient, user } = await requireUser(req);
    const { conversation_id, role } = await parseJSON<MarkReadPayload>(req);

    if (!conversation_id || !role) {
      throw new HTTPError(400, "conversation_id and role are required.");
    }

    if (role !== "host" && role !== "vendor") {
      throw new HTTPError(400, "role must be 'host' or 'vendor'.");
    }

    const { error } = await serviceClient.rpc("mark_messages_read", {
      p_conversation_id: conversation_id,
      p_role: role,
    });

    if (error) {
      const msg = error.message ?? "";
      if (msg.includes("not found")) throw new HTTPError(404, msg);
      if (msg.includes("Not authorized")) throw new HTTPError(403, msg);
      throw new HTTPError(500, msg);
    }

    return jsonResponse({ success: true });
  } catch (err) {
    return errorResponse(err);
  }
});
