// submit-external-booking
//
// Public (no JWT) endpoint. Accepts a booking request from someone who does
// not yet have the Plano app (App Clip or web form). Creates a real
// conversation + booking_request + claim invite token, and enqueues a
// "request received" email. Returns the conversation id and a claim token
// the success screen can include in an install CTA.
//
// Rate-limited by client IP at 10 submissions per hour to keep abuse off
// public vendor links.

import {
  corsHeaders,
  ensureMethod,
  errorResponse,
  HTTPError,
  jsonResponse,
  optionsResponse,
  parseJSON,
} from "../_shared/http.ts";
import { createServiceClient } from "../_shared/supabase.ts";

interface SubmitExternalBookingPayload {
  vendor_id: string;
  first_name: string;
  last_name: string;
  email: string;
  event_date: string;             // YYYY-MM-DD
  guest_count?: number | null;
  note?: string | null;
  intake_answers?: unknown[] | null;
  source?: "app_clip" | "web" | null;
}

interface SubmitExternalBookingResult {
  request_id: string;
}

const RATE_LIMIT_WINDOW_SECONDS = 3600;
const RATE_LIMIT_MAX = 10;

function clientIP(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for");
  if (forwarded) return forwarded.split(",")[0]!.trim();
  return request.headers.get("cf-connecting-ip") ??
    request.headers.get("x-real-ip") ??
    "unknown";
}

async function enforceRateLimit(
  // deno-lint-ignore no-explicit-any
  serviceClient: any,
  ip: string,
): Promise<void> {
  // Uses the existing analytics_events table as a lightweight rate bucket.
  // (Avoids a new table migration just for this; keyed by metadata.ip.)
  const since = new Date(Date.now() - RATE_LIMIT_WINDOW_SECONDS * 1000)
    .toISOString();

  const { count, error } = await serviceClient
    .from("analytics_events")
    .select("id", { count: "exact", head: true })
    .eq("event_type", "external_booking_submitted")
    .gte("created_at", since)
    .filter("metadata->>ip", "eq", ip);

  if (error) {
    console.warn("[submit-external-booking] rate-limit lookup failed:", error.message);
    return;
  }

  if ((count ?? 0) >= RATE_LIMIT_MAX) {
    throw new HTTPError(429, "Too many booking requests from this location. Please try again later.");
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const payload = await parseJSON<SubmitExternalBookingPayload>(request);

    if (!payload.vendor_id) {
      throw new HTTPError(400, "vendor_id is required.");
    }
    if (!payload.first_name?.trim() || !payload.last_name?.trim()) {
      throw new HTTPError(400, "First and last name are required.");
    }
    if (!payload.email?.trim() || !payload.email.includes("@")) {
      throw new HTTPError(400, "A valid email is required.");
    }
    if (!payload.event_date) {
      throw new HTTPError(400, "event_date is required.");
    }

    const serviceClient = createServiceClient();
    const ip = clientIP(request);

    await enforceRateLimit(serviceClient, ip);

    const { data, error } = await serviceClient
      .rpc("submit_external_booking_request", {
        p_vendor_id: payload.vendor_id,
        p_first_name: payload.first_name.trim(),
        p_last_name: payload.last_name.trim(),
        p_email: payload.email.trim(),
        p_event_date: payload.event_date,
        p_guest_count: payload.guest_count ?? null,
        p_note: payload.note ?? "",
        p_intake_answers: payload.intake_answers ?? [],
        p_source: payload.source ?? "web",
      });

    if (error) {
      const msg = error.message ?? "Failed to submit booking.";
      const status = msg.toLowerCase().includes("not found") ? 404 : 400;
      throw new HTTPError(status, msg);
    }

    const result = data as SubmitExternalBookingResult;

    // Analytics + rate-limit accounting.
    try {
      await serviceClient.from("analytics_events").insert({
        event_type: "external_booking_submitted",
        vendor_id: payload.vendor_id,
        metadata: {
          ip,
          source: payload.source ?? "web",
          request_id: result.request_id,
        },
      });
    } catch (analyticsError) {
      console.warn("[submit-external-booking] analytics insert failed:", analyticsError);
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  } catch (error) {
    return errorResponse(error);
  }
});
