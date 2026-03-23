import { ensureMethod, errorResponse, jsonResponse, optionsResponse, parseJSON, HTTPError } from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface CreateConversationPayload {
  vendor_id: string;
  event_id?: string;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<CreateConversationPayload>(request);

    const { data, error } = await serviceClient.rpc("create_conversation_server", {
      p_host_id: user.id,
      p_vendor_id: payload.vendor_id,
      p_event_id: payload.event_id ?? null,
    });

    if (error) {
      throw new HTTPError(400, error.message);
    }

    return jsonResponse(data);
  } catch (error) {
    return errorResponse(error);
  }
});
