import { BookingTransitionResult, runRPC } from "../_shared/booking.ts";
import { ensureMethod, errorResponse, jsonResponse, optionsResponse, parseJSON } from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface RequestPaymentPayload {
  conversation_id: string;
  amount_cents: number;
  note?: string;
  payment_type?: string;
  idempotency_key?: string;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<RequestPaymentPayload>(request);

    const result = await runRPC<BookingTransitionResult>(
      serviceClient,
      "request_payment_server",
      {
        p_conversation_id: payload.conversation_id,
        p_vendor_id: user.id,
        p_amount_cents: payload.amount_cents,
        p_note: payload.note ?? null,
        p_payment_type: payload.payment_type ?? "deposit",
        p_idempotency_key: payload.idempotency_key ?? null,
      },
    );

    return jsonResponse(result);
  } catch (error) {
    return errorResponse(error);
  }
});
