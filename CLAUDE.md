# Plano

## Product Context
- `Plano` is an iPhone-first party planning marketplace for two user types:
  - **Hosts** discover vendors, compare options, chat, and request bookings for events.
  - **Vendors** manage leads, respond to messages, review pending requests, and track confirmed upcoming events.
- The product bar is high: the app should feel calm, premium, native, and minimal, with the restraint and responsiveness of a strong Apple-designed app.
- Search, messaging, booking, and event status clarity are the core product pillars. If a decision weakens one of those, reconsider it.

## Current Codebase State
- The codebase is in Phase 3 (Live Booking Foundation) with 231 Swift files across 16 feature modules.
- Core architecture (service container, feature stores, realtime, offline queue) is established.
- Align new work to the existing structure rather than introducing parallel patterns.

## Design North Star
- Prefer quiet, high-contrast layouts with generous spacing and clear visual hierarchy.
- Remove decorative UI unless it improves comprehension, focus, or trust.
- Use motion sparingly and purposefully: view transitions, booking state changes, send-message feedback, and important confirmations.
- Favor native gestures, materials, typography, haptics, sheets, context menus, and navigation patterns over custom UI chrome.
- Optimize for one-handed iPhone use first. Tablet adaptations come after the phone experience feels complete.
- Avoid UI that looks like a generic marketplace clone. The app should feel editorial, precise, and service-oriented.

## Platform Strategy
- Build with `SwiftUI` first and use UIKit only when a missing capability forces it.
- Target iOS 26 APIs for primary experiences.
- If wider OS support becomes a business requirement, add compatibility work explicitly instead of diluting the primary architecture up front.
- Keep the initial product as a single app with role-based experiences for host and vendor. Split into multiple apps only if growth proves the workflows are diverging enough to justify the maintenance cost.

## Technical Direction
- Use `@Observable` models and services for UI-facing state.
- Use `SwiftData` as an on-device cache, draft store, and offline support layer, not the global source of truth for marketplace data.
- Use `async/await`, structured concurrency, and actors for networking, sync, and realtime state coordination.
- Target Swift 6.2 with strict concurrency checking.
- Consider default main-actor isolation for the app module.
- Use `@concurrent` for CPU offloading (image processing, heavy transforms).
- Name tasks and task group children for debugging/tracing.
- Keep business rules out of SwiftUI view bodies.
- Prefer feature-oriented folders over type-oriented folders.
- Default to `NavigationStack`, modern `Tab` APIs, `searchable`, and scene-based navigation.
- Add `OSLog`, signposts, and `MetricKit` instrumentation early so performance regressions are visible before the app gets complex.

## Concurrency Patterns

### Service actors
- Use actors for shared mutable state (auth tokens, draft cache, booking coordinator).
- Watch for reentrancy in the booking flow where transitions depend on server responses — after every `await`, re-validate state before mutating.

### Realtime
- Supabase realtime channels → `AsyncStream` via `makeStream(of:)`.
- Specify buffering policy for high-throughput channels (typing indicators).
- Finish continuations in ALL cleanup paths to avoid leaked streams.

### Offline queue
- Actor-serialized writes with task group batch retry, not unstructured tasks in loops.

### Cancellation
- All search, message, and booking tasks must handle `CancellationError` silently.
- Use `.task(id:)` for search debouncing. Cancel previous submissions before starting new ones.

### Background work
- Image resizing, media compression, search ranking → `@concurrent`.
- Do not assume `nonisolated` async runs off the main actor (Swift 6.2 changed this).

## Project Structure
```
Plano/App           - app entry, scene setup, dependency wiring
Plano/Core          - shared primitives, routing, formatting, logging, networking, auth, design tokens
Plano/DesignSystem  - reusable UI components, typography, spacing, surfaces, feedback, motion
Plano/Features/
  Onboarding/
  Search/
  VendorProfile/
  Inbox/
  Booking/
  EventWorkspace/
  VendorDashboard/
  Profile/
Plano/Data          - local persistence, sync, DTO mapping
Plano/PreviewSupport
PlanoTests/
PlanoUITests/
```

## Product Architecture

### Host Experience
- Event setup, vendor discovery, vendor profile review
- Chat, booking request flow, event workspace and timeline

### Vendor Experience
- Lead intake, response speed, availability
- Quote management, pending requests, confirmed events, day-of-event clarity

## Backend
- **Stack**: Supabase (Postgres-backed) for auth, database, storage, realtime transport, and server functions.
- **Payments**: Stripe Connect for deposits, payment capture, refunds, and vendor payouts.
- **Notifications**: APNs.
- Use server-side functions for all booking transitions, payment operations, idempotency checks, and authorization-sensitive message actions.
- Do not let the client finalize booking state on its own.
- **Keep Supabase in sync**: When any change requires Supabase updates (schema migrations, edge functions, RLS policies, storage buckets, etc.), deploy those changes immediately so the app is always functional when run. Never leave the app in a state where it depends on Supabase resources that haven't been deployed yet.

## Core Domain Model
`User`, `HostProfile`, `VendorProfile`, `VendorCategory`, `VendorService`, `VendorPackage`, `AvailabilityWindow`, `Event`, `EventGuestRange`, `BookingRequest`, `BookingQuote`, `Booking`, `Conversation`, `Message`, `Attachment`, `NotificationPreference`, `Review`, `SavedVendor`

## Booking State Machine
States: `draft` → `requested` → `vendor_reviewing` → `quoted` → `host_reviewing` → `accepted` → `deposit_pending` → `confirmed` → `completed`
Also: `declined`, `cancelled`
- Every transition must be auditable and idempotent.
- Availability conflicts, expired quotes, duplicate deposits, and stale client state must be handled server-side.

## Search Principles
- Support text query, location, date, category, price band, rating, and availability-aware filtering.
- Results should feel immediate. Use pagination, prefetching, and skeleton states.
- Vendor cards expose: image, name, category, location, price signal, rating, next availability signal.

## Messaging Principles
- Chat is a product surface, not a secondary utility.
- Support: delivery state, read state, typing indication, attachments, quick replies, quote and booking cards inline, unread count sync.
- Group inbox by event and vendor context. Never hide booking-critical state behind ambiguous labels.

## iOS Feature Guidance
- `ActivityKit` for active booking and event countdown Live Activities.
- `App Intents` / `App Shortcuts` for actions like opening today's events, jumping to pending requests, or searching vendors.
- `TipKit` sparingly for feature discovery.
- `MapKit` for vendor discovery, location previews, and event venue context.
- Consider `Foundation Models` framework only for bounded features (summarizing threads, extracting action items, drafting replies). Keep optional.
- Prefer `Apple Pay` for checkout when it reduces friction.

## Performance Rules
- No network calls, heavy mapping, or filtering inside view bodies.
- Paginate vendor search and message history.
- Precompute display models for large lists.
- Cache media aggressively and size images correctly.
- Measure launch time, scroll hitching, message send latency, and booking submission latency.
- Treat placeholder shimmer, optimistic updates, and skeletons as performance UX.

## Quality Bar
- Build after meaningful edits.
- Add tests for reducers, services, booking rules, and sync edge cases.
- Prefer `Swift Testing` for new unit coverage unless an existing target already standardizes on `XCTest`.
- Use `confirmation()` for async event testing, not timing-based waits.
- Enable Thread Sanitizer (TSan) in test scheme for CI.
- Add previews for major views and state variants.
- Validate dark mode, dynamic type, loading, empty, error, offline, and stale-data states.

## Delivery Plan
- The detailed roadmap lives in `docs/implementation-plan.md`.
- Before starting a major phase, confirm the phase scope, success criteria, and data contracts.

## Store Dependencies
- InboxStore: hub — consumed by EventWorkspaceStore, VendorDashboardStore, RequestsStore
- EventWorkspaceStore: reads from HostPlanningStore, InboxStore, VendorDashboardStore
- SearchStore: reads from HostPlanningStore
- VendorDashboardStore: reads from InboxStore
- RequestsStore: reads from HostPlanningStore, InboxStore

## Working Rules
- Read this file and the implementation plan before changing architecture.
- Make the minimum change that advances the current phase cleanly.
- Do not introduce speculative abstractions for future complexity that does not exist yet.
- Preserve the design direction: premium, quiet, fast, and trustworthy.
- When forced to choose, prioritize correctness in booking, clarity in chat, and responsiveness in search.

## Skill Usage
- Use `swiftui-pro` for any meaningful SwiftUI implementation, refactor, or review work.
- Use `swift-concurrency-pro` for concurrency implementation or review.
- Use `swiftui-view-refactor` when decomposing views.
- Treat skills as the default quality pass — load the relevant skill for the task at hand.
- When reviewing, report only genuine issues with file/line references, the violated rule, and a concise before/after fix.
- When implementing SwiftUI code, follow the skill's baseline assumptions:
  - Target modern Apple platform APIs with iOS 26 as the primary experience
  - Prefer SwiftUI over UIKit unless a missing capability forces UIKit
  - Avoid third-party frameworks unless explicitly approved
  - Keep types split into focused files
  - Preserve feature-oriented structure over type-oriented structure
