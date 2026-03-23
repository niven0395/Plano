import {
  ensureMethod,
  errorResponse,
  jsonResponse,
  optionsResponse,
  parseJSON,
  HTTPError,
} from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

interface RegisterDeviceTokenPayload {
  token: string;
  platform?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(req, "POST");

    const { serviceClient, user } = await requireUser(req);
    const { token, platform } = await parseJSON<RegisterDeviceTokenPayload>(req);

    if (!token || typeof token !== "string") {
      throw new HTTPError(400, "token is required and must be a non-empty string.");
    }

    if (!/^[a-fA-F0-9]+$/.test(token)) {
      throw new HTTPError(400, "token must be a valid hex string.");
    }

    const validPlatform = platform ?? "ios";
    if (validPlatform !== "ios" && validPlatform !== "macos") {
      throw new HTTPError(400, "platform must be 'ios' or 'macos'.");
    }

    // Upsert device token
    const { error: upsertError } = await serviceClient
      .from("device_tokens")
      .upsert(
        {
          user_id: user.id,
          token,
          platform: validPlatform,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id,token" },
      );

    if (upsertError) {
      throw new HTTPError(500, upsertError.message);
    }

    // Delete stale tokens (older than 90 days)
    const { error: deleteError } = await serviceClient
      .from("device_tokens")
      .delete()
      .eq("user_id", user.id)
      .lt("updated_at", new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString());

    if (deleteError) {
      console.error("Failed to clean stale tokens:", deleteError.message);
    }

    return jsonResponse({ ok: true });
  } catch (err) {
    return errorResponse(err);
  }
});
