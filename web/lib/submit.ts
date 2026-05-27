import { SUPABASE_ANON_KEY, SUPABASE_URL } from "./env";
import type { IntakeQuestion } from "./vendor";

export interface IntakeAnswer {
  questionID: string;
  prompt: string;
  responseType: IntakeQuestion["responseType"];
  values: string[];
}

export interface SubmitPayload {
  vendor_id: string;
  first_name: string;
  last_name: string;
  email: string;
  event_date: string; // YYYY-MM-DD
  guest_count?: number | null;
  note?: string | null;
  intake_answers?: IntakeAnswer[] | null;
  source: "web";
}

export interface SubmitResult {
  request_id: string;
}

export class SubmitError extends Error {
  readonly status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export async function submitBookingRequest(payload: SubmitPayload): Promise<SubmitResult> {
  const url = `${SUPABASE_URL}/functions/v1/submit-external-booking`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    let message = "Something went wrong. Please try again.";
    try {
      const body = (await res.json()) as { error?: string; message?: string };
      message = body.error ?? body.message ?? message;
    } catch {
      // ignore parse errors, keep default message
    }
    if (res.status === 429) {
      message = "Too many booking requests from this network. Please try again in a little while.";
    }
    throw new SubmitError(res.status, message);
  }

  return (await res.json()) as SubmitResult;
}
