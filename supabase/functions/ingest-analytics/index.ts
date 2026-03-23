import {
  ensureMethod,
  errorResponse,
  HTTPError,
  jsonResponse,
  optionsResponse,
  parseJSON,
} from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

const ALLOWED_EVENT_TYPES = new Set([
  "search_impression",
  "profile_view",
  "gallery_scroll",
  "social_link_click",
  "vendor_saved",
  "vendor_unsaved",
  "conversation_started",
]);

const MAX_BATCH_SIZE = 100;

interface AnalyticsEvent {
  event_type: string;
  vendor_id: string;
  event_id?: string;
  metadata?: Record<string, unknown>;
}

interface IngestPayload {
  events: AnalyticsEvent[];
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<IngestPayload>(request);

    if (!Array.isArray(payload.events) || payload.events.length === 0) {
      throw new HTTPError(400, "events array is required and must not be empty.");
    }

    if (payload.events.length > MAX_BATCH_SIZE) {
      throw new HTTPError(400, `Batch size exceeds maximum of ${MAX_BATCH_SIZE}.`);
    }

    for (const event of payload.events) {
      if (!ALLOWED_EVENT_TYPES.has(event.event_type)) {
        throw new HTTPError(400, `Invalid event_type: ${event.event_type}`);
      }
      if (!event.vendor_id) {
        throw new HTTPError(400, "vendor_id is required for each event.");
      }
    }

    const rows = payload.events.map((event) => ({
      event_type: event.event_type,
      vendor_id: event.vendor_id,
      actor_id: user.id,
      event_id: event.event_id ?? null,
      metadata: event.metadata ?? {},
    }));

    const { error } = await serviceClient.from("analytics_events").insert(rows);
    if (error) {
      throw new HTTPError(500, error.message);
    }

    return jsonResponse({ ingested: rows.length });
  } catch (error) {
    return errorResponse(error);
  }
});
