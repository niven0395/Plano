# Supabase Setup

## Local App Config

The app reads Supabase credentials from build settings that are injected into the generated Info.plist.

- Local secrets live in `Config/LocalSecrets.xcconfig`
- `Config/LocalSecrets.xcconfig` is gitignored
- `Config/LocalSecrets.example.xcconfig` shows the expected keys

Current required values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## Migrations In Repo

Apply these in order:

1. `supabase/migrations/20260306120000_phase1_auth_events.sql`
2. `supabase/migrations/20260307120000_phase2_vendor_profiles.sql`
3. `supabase/migrations/20260307153000_phase2_discovery_saved_vendors.sql`
4. `supabase/migrations/20260308120000_phase3_booking_system.sql`
5. `supabase/migrations/20260308150000_phase3_storage.sql`

## Dashboard Settings Needed

- Auth > Providers > Anonymous: enabled
- Auth > Security > Manual Linking: enabled

Apple auth is intentionally deferred until Apple Developer setup is ready.

## Remaining Hosted-Project Inputs

To link this repo and push migrations to the hosted project with the Supabase CLI, you still need:

- A Supabase personal access token for CLI auth
- The hosted database password for project `uytbxijaigrvkxpcbohm`
