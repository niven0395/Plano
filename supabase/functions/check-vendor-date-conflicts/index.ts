import { DateConflict, runRPC } from "../_shared/booking.ts";
import { HTTPError, ensureMethod, errorResponse, jsonResponse, optionsResponse, parseJSON } from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface CheckVendorDateConflictsPayload {
  vendor_id: string;
  event_date: string;
  exclude_conversation_id?: string;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<CheckVendorDateConflictsPayload>(request);

    if (payload.vendor_id !== user.id) {
      throw new HTTPError(403, "You can only inspect conflicts for your own vendor account.");
    }

    const conflicts = await runRPC<DateConflict[]>(
      serviceClient,
      "check_vendor_date_conflicts",
      {
        lookup_vendor_id: payload.vendor_id,
        lookup_event_date: payload.event_date,
        exclude_conversation_id: payload.exclude_conversation_id ?? null,
      },
    );

    return jsonResponse({ conflicts });
  } catch (error) {
    return errorResponse(error);
  }
});
