# Plano

Plano is an iPhone-first party planning marketplace for hosts and event vendors. Hosts can discover vendors, review profiles, message, and send booking requests. Vendors can manage leads, respond to messages, and track upcoming work.

The app is built to feel calm, native, and service-oriented while keeping booking, messaging, and availability state explicit.

## Recommended Evaluation Path

Use the TestFlight build for the fastest end-to-end test on a real device.

Suggested flow:

1. Create or sign in to an account.
2. Browse vendor categories from Home or Search.
3. Open a vendor profile and review packages, availability, policies, and category-specific details.
4. Send a booking request.
5. Open Inbox to view the conversation and booking context.
6. Open Planning to review request and booking state.
7. Switch to vendor mode from Profile if a vendor profile is available for the signed-in account.

## Run Locally

Requirements:

- macOS with the current Xcode release used for iOS development
- iOS Simulator or a physical iPhone

Setup:

1. Clone the repository.
2. Open `Plano.xcodeproj` in Xcode.
3. Select the `Plano` scheme.
4. Build and run.

The repository includes `Config/DemoSupabase.xcconfig`, which points local builds at the demo Supabase backend so auth, discovery, messaging, and booking can be tested immediately after cloning.

Optional private backend setup:

1. Copy `Config/LocalSecrets.example.xcconfig` to `Config/LocalSecrets.xcconfig`.
2. Add the Supabase URL and anon key for your own project.

`Config/LocalSecrets.xcconfig` is intentionally ignored by Git and overrides the tracked demo config when present.

## Architecture Highlights

- SwiftUI-first iOS app with Observation-based feature stores.
- Feature-oriented structure under `Plano/Features`.
- Supabase/Postgres backend with server-side booking and messaging functions.
- SwiftData-backed local message cache.
- Explicit booking states instead of loose boolean flags.
- Swift Testing coverage for auth, discovery, booking transitions, messaging reliability, realtime decoding, and vendor dashboard behavior.

## Repository Layout

- `Plano/App`: app entry, root navigation, dependency wiring
- `Plano/Core`: models, routing, services, networking, logging, app state
- `Plano/DesignSystem`: shared UI components, styling, feedback, and surfaces
- `Plano/Features`: product features such as Search, Inbox, Booking, Vendor Profile, Planning, and Vendor Dashboard
- `Plano/Data`: local persistence and message cache
- `PlanoTests`: unit and integration-style tests
- `supabase`: database migrations and Edge Functions
- `web`: external booking web flow
- `docs`: setup and implementation notes

## Notes

This repository does not include local secrets, generated dependency folders, or personal agent/tooling files. TestFlight is the intended path for product evaluation; local builds are useful for code review and architecture inspection.
