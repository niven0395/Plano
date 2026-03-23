import { ensureMethod, errorResponse, jsonResponse, optionsResponse, parseJSON, HTTPError } from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface VendorSearchPayload {
  query?: string;
  category?: string;
  city?: string;
  event_date?: string;
  price_min?: number;
  price_max?: number;
  limit?: number;
  offset?: number;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient } = await requireUser(request);
    const payload = await parseJSON<VendorSearchPayload>(request);

    const { data, error } = await serviceClient.rpc("search_vendors_server", {
      p_query: payload.query ?? null,
      p_category: payload.category ?? null,
      p_city: payload.city ?? null,
      p_event_date: payload.event_date ?? null,
      p_price_min: payload.price_min ?? null,
      p_price_max: payload.price_max ?? null,
      p_limit: payload.limit ?? 24,
      p_offset: payload.offset ?? 0,
    });

    if (error) {
      throw new HTTPError(400, error.message);
    }

    return jsonResponse(data ?? []);
  } catch (error) {
    return errorResponse(error);
  }
});
