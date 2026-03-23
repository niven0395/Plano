import { BookingTransitionResult, runRPC } from "../_shared/booking.ts";
import { ensureMethod, errorResponse, jsonResponse, optionsResponse, parseJSON } from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface SubmitBookingV2Payload {
  conversation_id: string;
  event_date: string;
  note?: string;
  idempotency_key?: string;
  requested_time_start?: string;
  requested_time_end?: string;
  title?: string;
  budget_label?: string;
  guest_count_label?: string;
  requested_services?: string[];
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<SubmitBookingV2Payload>(request);

    const result = await runRPC<BookingTransitionResult>(
      serviceClient,
      "submit_booking_request_v2",
      {
        p_conversation_id: payload.conversation_id,
        p_host_id: user.id,
        p_event_date: payload.event_date,
        p_note: payload.note ?? "",
        p_idempotency_key: payload.idempotency_key ?? null,
        p_requested_time_start: payload.requested_time_start ?? null,
        p_requested_time_end: payload.requested_time_end ?? null,
        p_title: payload.title ?? null,
        p_budget_label: payload.budget_label ?? null,
        p_guest_count_label: payload.guest_count_label ?? null,
        p_requested_services: payload.requested_services ?? null,
      },
    );

    // Analytics side-effect: track booking_requested
    try {
      const { data: conv } = await serviceClient
        .from("conversations")
        .select("vendor_id")
        .eq("id", payload.conversation_id)
        .single();

      await serviceClient.from("analytics_events").insert({
        event_type: "booking_requested",
        vendor_id: conv?.vendor_id ?? null,
        actor_id: user.id,
        event_id: result.booking_id ?? null,
        metadata: {},
      });
    } catch (analyticsError) {
      console.warn("Analytics insert failed (submit-booking-v2):", analyticsError);
    }

    return jsonResponse(result);
  } catch (error) {
    return errorResponse(error);
  }
});
