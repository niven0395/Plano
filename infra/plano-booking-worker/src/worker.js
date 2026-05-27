// plano-booking — Cloudflare Worker
//
// Thin reverse proxy in front of the `plano-web` Worker (Next.js app built
// with @opennextjs/cloudflare). The plano-booking host is the stable
// identity in iOS entitlements and shared booking links; the Next.js
// deployment can evolve behind it without touching the Clip.
//
// Uses a Cloudflare service binding (`env.NEXTJS_APP`) instead of a public
// fetch to avoid the workers.dev loop-protection rejection that happens
// when one workers.dev subdomain calls another directly.
//
// Routes:
//   /.well-known/apple-app-site-association → NEXTJS_APP /.well-known/…   (AASA)
//   /book/*                                   → NEXTJS_APP /book/*        (Next.js UI)
//   /functions/v1/book/*                      → NEXTJS_APP /book/*        (legacy)
//   everything else                           → NEXTJS_APP (passthrough)

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Rewrite legacy /functions/v1/book/* URLs (emitted by the old Supabase
    // form action) to the canonical /book/* path.
    const rewrittenPath = url.pathname.startsWith("/functions/v1/book")
      ? url.pathname.replace("/functions/v1", "")
      : url.pathname;

    const upstreamURL = new URL(rewrittenPath + url.search, "https://plano-web.internal");

    // Build a fresh Request so the host/origin don't leak through and the
    // service binding can rewrite freely. Drop Cloudflare-injected noise.
    const forwardedHeaders = new Headers(request.headers);
    for (const drop of ["host", "cf-connecting-ip", "cf-ray", "cf-visitor", "cf-ipcountry"]) {
      forwardedHeaders.delete(drop);
    }

    const upstreamRequest = new Request(upstreamURL.toString(), {
      method: request.method,
      headers: forwardedHeaders,
      body: ["GET", "HEAD"].includes(request.method) ? undefined : request.body,
      redirect: "manual",
    });

    const response = await env.NEXTJS_APP.fetch(upstreamRequest);

    // Rewrite Location header on redirects so browsers stay on this host.
    const outHeaders = new Headers(response.headers);
    const location = outHeaders.get("location");
    if (location) {
      const loc = new URL(location, upstreamURL);
      outHeaders.set("location", loc.pathname + loc.search);
    }
    outHeaders.delete("content-security-policy");

    return new Response(response.body, {
      status: response.status,
      headers: outHeaders,
    });
  },
};
