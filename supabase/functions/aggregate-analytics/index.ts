import { createServiceClient } from "../_shared/supabase.ts";
import {
  ensureMethod,
  errorResponse,
  HTTPError,
  jsonResponse,
  optionsResponse,
} from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(req, "POST");
    const serviceClient = createServiceClient();

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const aggregatedDate = yesterday.toISOString().split("T")[0];

    const { error } = await serviceClient.rpc("aggregate_vendor_analytics_daily", {
      target_date: aggregatedDate,
    });
    if (error) throw new HTTPError(500, error.message);

    console.log(`Aggregated analytics for ${aggregatedDate}`);

    return jsonResponse({ aggregated_date: aggregatedDate, status: "ok" });
  } catch (err) {
    return errorResponse(err);
  }
});
