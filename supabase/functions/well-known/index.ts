// well-known
//
// Serves apple-app-site-association (AASA) for Universal Links so iOS devices
// with Plano installed open booking links directly in the app instead of the
// browser. Apple fetches AASA from the apex `/.well-known/...` path of each
// Associated Domain — this Supabase function is kept as a fallback source of
// the JSON, but the canonical production host is the Cloudflare Worker that
// serves Next.js, which mirrors this shape.

import { corsHeaders } from "../_shared/http.ts";

function env(name: string, fallback: string): string {
  return Deno.env.get(name) ?? fallback;
}

Deno.serve((_request) => {
  const mainAppID = env("APP_BUNDLE_ID_FULL", "TEAMID.com.plano.app");

  const body = {
    applinks: {
      apps: [],
      details: [
        {
          appIDs: [mainAppID],
          components: [
            { "/": "/book/*" },
            { "/": "/functions/v1/book/*" },
            { "/": "/claim*" },
            { "/": "/functions/v1/book/claim*" },
          ],
        },
      ],
    },
  };

  return new Response(JSON.stringify(body, null, 2), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-cache",
    },
  });
});
