// claim-external-booking
//
// Requires a Supabase auth JWT. Accepts either an invite token (from an email
// deep link) or no token (sweeping all pending invites for the signed-in
// user's email). Returns the list of claimed conversation ids so the client
// can route to them.

import {
  ensureMethod,
  errorResponse,
  HTTPError,
  jsonResponse,
  optionsResponse,
  parseJSON,
} from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface ClaimPayload {
  token?: string | null;
}

interface ClaimResult {
  conversation_ids: string[];
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<ClaimPayload>(request).catch(() => ({} as ClaimPayload));

    const email = (user.email ?? "").toLowerCase().trim();
    if (!email) {
      throw new HTTPError(400, "Authenticated user has no email on record.");
    }

    const claimed: string[] = [];

    // 1. Explicit token path (user tapped an email link).
    if (payload?.token) {
      const { data, error } = await serviceClient.rpc("claim_external_booking", {
        p_user_id: user.id,
        p_user_email: email,
        p_token: payload.token,
      });

      if (error) {
        const msg = error.message ?? "Claim failed.";
        const normalized = msg.toLowerCase();
        let status = 400;
        if (normalized.includes("expired") || normalized.includes("already")) status = 409;
        if (normalized.includes("not found")) status = 404;
        if (normalized.includes("different email")) status = 403;
        throw new HTTPError(status, msg);
      }

      const conversationID = (data as { conversation_id: string }).conversation_id;
      claimed.push(conversationID);
    }

    // 2. Sweep any unclaimed invites that match this user's email.
    const { data: pending, error: listError } = await serviceClient
      .rpc("list_claimable_invites_for_email", { p_email: email });

    if (listError) {
      console.warn("[claim-external-booking] list lookup failed:", listError.message);
    } else if (pending) {
      for (const invite of pending as Array<{ token: string; conversation_id: string }>) {
        if (claimed.includes(invite.conversation_id)) continue;
        const { data: claimData, error: claimError } = await serviceClient
          .rpc("claim_external_booking", {
            p_user_id: user.id,
            p_user_email: email,
            p_token: invite.token,
          });
        if (claimError) {
          console.warn(
            `[claim-external-booking] claim failed for token ${invite.token}:`,
            claimError.message,
          );
          continue;
        }
        claimed.push((claimData as { conversation_id: string }).conversation_id);
      }
    }

    const result: ClaimResult = { conversation_ids: claimed };
    return jsonResponse(result);
  } catch (error) {
    return errorResponse(error);
  }
});
