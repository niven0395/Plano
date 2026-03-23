import { BookingTransitionResult, runRPC } from "../_shared/booking.ts";
import { ensureMethod, errorResponse, jsonResponse, optionsResponse, parseJSON } from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface DeclineRequestPayload {
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
    const payload = await parseJSON<DeclineRequestPayload>(request);

    const result = await runRPC<BookingTransitionResult>(
      serviceClient,
      "decline_request_server",
      {
        p_conversation_id: payload.conversation_id,
        p_vendor_id: user.id,
        p_reason: payload.reason ?? null,
        p_idempotency_key: payload.idempotency_key ?? null,
      },
    );

    return jsonResponse(result);
  } catch (error) {
    return errorResponse(error);
  }
});
