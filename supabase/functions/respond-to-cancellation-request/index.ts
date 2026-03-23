import { BookingTransitionResult, runRPC } from "../_shared/booking.ts";
import { ensureMethod, errorResponse, jsonResponse, optionsResponse, parseJSON } from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface RespondToCancellationPayload {
  conversation_id: string;
  approved: boolean;
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
    const payload = await parseJSON<RespondToCancellationPayload>(request);

    const result = await runRPC<BookingTransitionResult>(
      serviceClient,
      "respond_to_cancellation_request_v2",
      {
        p_conversation_id: payload.conversation_id,
        p_responder_id: user.id,
        p_approved: payload.approved,
        p_reason: payload.reason ?? null,
        p_idempotency_key: payload.idempotency_key ?? null,
      },
    );

    // Analytics side-effect: track cancellation_request_responded
    try {
      const { data: conv } = await serviceClient
        .from("conversations")
        .select("vendor_id")
        .eq("id", payload.conversation_id)
        .single();

      await serviceClient.from("analytics_events").insert({
        event_type: "cancellation_request_responded",
        vendor_id: conv?.vendor_id ?? null,
        actor_id: user.id,
        metadata: {
          conversation_id: payload.conversation_id,
          approved: payload.approved,
        },
      });
    } catch (analyticsError) {
      console.warn("Analytics insert failed (respond-to-cancellation-request):", analyticsError);
    }

    return jsonResponse(result);
  } catch (error) {
    return errorResponse(error);
  }
});
