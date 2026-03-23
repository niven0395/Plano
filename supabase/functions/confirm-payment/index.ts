import { BookingTransitionResult, runRPC } from "../_shared/booking.ts";
import {
  ensureMethod,
  errorResponse,
  jsonResponse,
  optionsResponse,
  parseJSON,
} from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface ConfirmPaymentPayload {
  conversation_id: string;
  idempotency_key?: string;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<ConfirmPaymentPayload>(request);

    const result = await runRPC<BookingTransitionResult>(
      serviceClient,
      "confirm_payment_server",
      {
        p_conversation_id: payload.conversation_id,
        p_host_id: user.id,
        p_idempotency_key: payload.idempotency_key ?? null,
      },
    );

    // Non-blocking analytics
    serviceClient
      .from("analytics_events")
      .insert({
        event_type: "booking_confirmed",
        vendor_id: null,
        actor_id: user.id,
        metadata: { conversation_id: payload.conversation_id, role: "host" },
      })
      .then(({ error }) => {
        if (error) console.warn("analytics insert failed:", error.message);
      });

    return jsonResponse(result);
  } catch (error) {
    return errorResponse(error);
  }
});
