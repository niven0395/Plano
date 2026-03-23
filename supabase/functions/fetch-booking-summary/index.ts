import { ensureMethod, errorResponse, jsonResponse, optionsResponse, parseJSON, HTTPError } from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface FetchBookingSummaryPayload {
  role: string;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<FetchBookingSummaryPayload>(request);

    if (payload.role !== "host" && payload.role !== "vendor") {
      throw new HTTPError(400, "Role must be 'host' or 'vendor'.");
    }

    const { data, error } = await serviceClient.rpc("fetch_booking_summaries", {
      p_user_id: user.id,
      p_role: payload.role,
    });

    if (error) {
      throw new HTTPError(400, error.message);
    }

    return jsonResponse(data ?? []);
  } catch (error) {
    return errorResponse(error);
  }
});
