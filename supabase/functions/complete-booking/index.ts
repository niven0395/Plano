import { createServiceClient } from "../_shared/supabase.ts";
import {
  ensureMethod,
  errorResponse,
  jsonResponse,
  optionsResponse,
  HTTPError,
} from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(req, "POST");
    const serviceClient = createServiceClient();

    const { data, error } = await serviceClient.rpc("complete_past_bookings");
    if (error) throw new HTTPError(500, error.message);

    const results = data ?? [];
    console.log(`Completed ${results.length} past bookings`);

    // Analytics side-effect: track booking_completed for each result
    for (const booking of results) {
      try {
        const conversationId = booking.conversation_id;
        const { data: conv } = await serviceClient
          .from("conversations")
          .select("vendor_id")
          .eq("id", conversationId)
          .single();

        await serviceClient.from("analytics_events").insert({
          event_type: "booking_completed",
          vendor_id: conv?.vendor_id ?? null,
          actor_id: null,
          metadata: {},
        });
      } catch (analyticsError) {
        console.warn("Analytics insert failed (complete-booking):", analyticsError);
      }
    }

    return jsonResponse({ completed_count: results.length, results });
  } catch (err) {
    return errorResponse(err);
  }
});
