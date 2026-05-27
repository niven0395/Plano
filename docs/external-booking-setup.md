# External Booking Setup (Web)

This document covers the manual steps needed to run the external-booking
feature end-to-end: vendors share one link, non-app users submit a booking
request on the Next.js web page, state transitions trigger emails, and the
external host can claim the thread once they install Plano.

## 1. Supabase deploy

```bash
# Apply the new migration
supabase db push

# Deploy the edge functions
supabase functions deploy \
  submit-external-booking \
  claim-external-booking \
  send-external-booking-email \
  book \
  well-known
```

Set the following edge-function secrets (`supabase secrets set ...`):

| Variable | Purpose |
|---|---|
| `RESEND_API_KEY` | Send guest-host emails via Resend |
| `EMAIL_FROM` | Verified from address, e.g. `Plano <noreply@plano.app>` |
| `PUBLIC_APP_DOMAIN` | Hostname used to build `/claim` URLs in emails, e.g. `plano-booking.nivensivarajah.workers.dev` |
| `APP_BUNDLE_ID_FULL` | Team ID + bundle id of main app, e.g. `FSRNNZN4V3.com.niven.plano` |

Schedule the email drainer to run every minute:

```sql
-- in Supabase SQL editor (enable pg_cron first if needed)
select cron.schedule(
  'drain-external-email-jobs',
  '* * * * *',
  $$
    select net.http_post(
      url := 'https://<project-ref>.supabase.co/functions/v1/send-external-booking-email',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true),
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object('batch_size', 25)
    );
  $$
);
```

(If you prefer, call the drainer manually from the terminal during dev:
`curl -X POST -H "Authorization: Bearer $SERVICE_ROLE_KEY" https://<ref>.supabase.co/functions/v1/send-external-booking-email -d '{}'`.)

## 2. Apple Associated Domains / AASA (Universal Links)

The canonical public host is the Cloudflare Worker at
`https://plano-booking.nivensivarajah.workers.dev`. It serves AASA at
`/.well-known/apple-app-site-association` and proxies `/book/*` to the
Next.js app via a service binding.

When `applinks:plano-booking.nivensivarajah.workers.dev` is present in
`Plano/Plano.entitlements` and the AASA lists the main app's bundle ID,
iOS devices with Plano installed open a tapped booking link directly in
the app. Devices without Plano fall through to the Next.js booking page.

## 3. Deferred follow-ups

- **Inbox badge/banner for guest conversations.** The vendor sees external
  requests in their inbox alongside in-app ones, but without a visual "guest,
  emails until install" indicator.
- **Attach real App Store app id.** Replace `id0000000000` in
  `supabase/functions/book/index.ts` and `supabase/functions/send-external-booking-email/index.ts`
  once the app is on the store.
- **Custom domain migration.** Switch from `plano-booking.nivensivarajah.workers.dev`
  to a branded domain (requires updating entitlements + AASA).

## 4. Smoke test

```bash
# 1. AASA reachable at the Worker apex
curl -sSf https://plano-booking.nivensivarajah.workers.dev/.well-known/apple-app-site-association | jq .

# 2. Next.js booking page renders through the Worker
curl -sS -D - "https://plano-booking.nivensivarajah.workers.dev/book/<vendor_id>" -o /tmp/book.html

# 3. Submit via JSON
curl -X POST -H "Content-Type: application/json" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  "https://<ref>.supabase.co/functions/v1/submit-external-booking" \
  -d '{"vendor_id":"<uuid>","first_name":"Alex","last_name":"Test","email":"alex@example.com","event_date":"2026-05-10","source":"web"}'

# 4. Drain the email queue (service-role key)
curl -X POST -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  "https://<ref>.supabase.co/functions/v1/send-external-booking-email" \
  -d '{}'
```

Verify in the Plano app (signed in as the vendor): the new conversation
appears in the inbox, tapping it shows the booking request, and accepting /
declining it triggers the email. Signing in on another simulator as a host
with the submission email claims the conversation via the post-sign-in sweep.
