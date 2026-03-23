import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { HTTPError } from "./http.ts";

export interface DateConflict {
  conversation_id: string;
  event_title: string;
  host_display_name: string;
  stage: string;
}

export interface BookingTransitionResult {
  conversation_id: string;
  stage: string;
  booking_id: string | null;
  date_conflicts?: DateConflict[];
  quote_id?: string;
}

export async function runRPC<T>(
  serviceClient: SupabaseClient,
  functionName: string,
  params: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await serviceClient.rpc(functionName, params).single();
  if (error) {
    throw mapDatabaseError(error.message);
  }
  if (data === null || data === undefined) {
    throw new HTTPError(500, "Database function returned no data.");
  }

  return data as T;
}

function mapDatabaseError(message: string): HTTPError {
  const normalized = message.toLowerCase();

  if (normalized.includes("not found")) {
    return new HTTPError(404, message);
  }

  if (normalized.includes("only ") || normalized.includes("participant")) {
    return new HTTPError(403, message);
  }

  if (
    normalized.includes("expired") ||
    normalized.includes("already") ||
    normalized.includes("cannot") ||
    normalized.includes("required")
  ) {
    return new HTTPError(409, message);
  }

  return new HTTPError(400, message);
}
