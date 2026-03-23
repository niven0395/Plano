import { BookingTransitionResult, runRPC } from "../_shared/booking.ts";
import { ensureMethod, errorResponse, jsonResponse, optionsResponse, parseJSON } from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface DeclineBookingPayload {
  conversation_id: string;
  reason?: string;
  idempotency_key?: string;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<DeclineBookingPayload>(request);

    const result = await runRPC<BookingTransitionResult>(
      serviceClient,
      "decline_booking_server",
      {
        p_conversation_id: payload.conversation_id,
        p_vendor_id: user.id,
        p_reason: payload.reason ?? null,
        p_idempotency_key: payload.idempotency_key ?? null,
      },
    );

    // Analytics side-effect: track booking_declined (vendor is the actor)
    try {
      await serviceClient.from("analytics_events").insert({
        event_type: "booking_declined",
        vendor_id: user.id,
        actor_id: user.id,
        metadata: {},
      });
    } catch (analyticsError) {
      console.warn("Analytics insert failed (decline-booking):", analyticsError);
    }

    return jsonResponse(result);
  } catch (error) {
    return errorResponse(error);
  }
});
