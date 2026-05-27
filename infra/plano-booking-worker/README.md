# plano-booking Cloudflare Worker

Stable public host for shared booking links. Proxies `/book/*` (and the
legacy `/functions/v1/book/*` path) plus `/.well-known/apple-app-site-association`
to the Next.js app via a service binding, so:

1. Vendors share a consistent URL (`plano-booking.<account>.workers.dev`)
   pinned by `applinks:` in the iOS entitlements — taps on iPhone with
   Plano installed open in-app, others land on the Next.js booking page.
2. AASA is served at the apex path Apple's CDN requires for Universal Links.

## Deploy

One-time setup:

```bash
# 1. Install wrangler (Cloudflare's CLI)
npm install -g wrangler

# 2. Sign in — opens browser for Cloudflare auth. Free account is fine.
wrangler login

# 3. Deploy
cd infra/plano-booking-worker
wrangler deploy
```

Wrangler prints the deployed URL on success, e.g.
`https://plano-booking.<your-account>.workers.dev`. Note that host — every
subsequent step needs it.

## After first deploy

1. **Verify AASA**:
   ```bash
   curl -sSf https://plano-booking.<account>.workers.dev/.well-known/apple-app-site-association | jq .
   ```
   Should return the same JSON the Supabase `well-known` function serves.

2. **Verify booking page renders HTML**:
   ```bash
   curl -sS -D - https://plano-booking.<account>.workers.dev/book/c1a34c8d-5832-48e2-8178-b78cbef5353e -o /tmp/book.html
   ```
   Headers should show `content-type: text/html; charset=utf-8` (not
   `text/plain`).

3. **Update iOS app entitlements** to point `applinks:` at the new host.

## Updating

Any time you change `src/worker.js`:

```bash
wrangler deploy
```

Redeploys in seconds, no downtime.
