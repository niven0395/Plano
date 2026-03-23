# AGENTS.md

## Product Context
- `Plano` is an iPhone-first party planning marketplace for two user types:
- Hosts discover vendors, compare options, chat, and request bookings for events.
- Vendors manage leads, respond to messages, review pending requests, and track confirmed upcoming events.
- The product bar is high: the app should feel calm, premium, native, and minimal, with the restraint and responsiveness people expect from a strong Apple-designed app.
- Search, messaging, booking, and event status clarity are the core product pillars. If a decision weakens one of those, reconsider it.

## Current Codebase State
- The repository currently contains the default SwiftUI + SwiftData starter app.
- Treat the current app as scaffolding, not architecture.
- Before large implementation work, align the codebase to the target structure described below instead of layering features onto the starter template.

## Design North Star
- Prefer quiet, high-contrast layouts with generous spacing and clear visual hierarchy.
- Remove decorative UI unless it improves comprehension, focus, or trust.
- Use motion sparingly and purposefully: view transitions, booking state changes, send-message feedback, and important confirmations.
- Favor native gestures, materials, typography, haptics, sheets, context menus, and navigation patterns over custom UI chrome.
- Optimize for one-handed iPhone use first. Tablet adaptations come after the phone experience feels complete.
- Avoid UI that looks like a generic marketplace clone. The app should feel editorial, precise, and service-oriented.

## Platform Strategy
- Build with `SwiftUI` first and use UIKit only when a missing capability forces it.
- Design around the latest Apple platform capabilities, with an assumption that iOS 26 APIs are available for primary experiences.
- If wider OS support becomes a business requirement, add compatibility work explicitly instead of diluting the primary architecture up front.
- Keep the initial product as a single app with role-based experiences for host and vendor. Split into multiple apps only if growth proves the workflows are diverging enough to justify the maintenance cost.

## Technical Direction
- Use `@Observable` models and services for UI-facing state.
- Use `SwiftData` as an on-device cache, draft store, and offline support layer, not the global source of truth for marketplace data.
- Use `async/await`, structured concurrency, and actors for networking, sync, and realtime state coordination.
- Keep business rules out of SwiftUI view bodies.
- Prefer feature-oriented folders over type-oriented folders.
- Default to `NavigationStack`, modern `Tab` APIs, `searchable`, and scene-based navigation.
- Add `OSLog`, signposts, and `MetricKit` instrumentation early so performance regressions are visible before the app gets complex.

## Recommended Project Shape
- `Plano/App`: app entry, scene setup, dependency wiring.
- `Plano/Core`: shared primitives, routing, formatting, logging, networking, auth, design tokens.
- `Plano/DesignSystem`: reusable UI components, typography, spacing, surfaces, feedback, and motion.
- `Plano/Features/Onboarding`
- `Plano/Features/Search`
- `Plano/Features/VendorProfile`
- `Plano/Features/Inbox`
- `Plano/Features/Booking`
- `Plano/Features/EventWorkspace`
- `Plano/Features/VendorDashboard`
- `Plano/Features/Profile`
- `Plano/Data`: local persistence, sync, DTO mapping.
- `Plano/PreviewSupport`
- `PlanoTests` and `PlanoUITests`

## Product Architecture
- The host experience should center around:
- event setup
- vendor discovery
- vendor profile review
- chat
- booking request flow
- event workspace and timeline
- The vendor experience should center around:
- lead intake
- response speed
- availability
- quote management
- pending requests
- confirmed events
- day-of-event clarity

## Backend Recommendation
- Use a relational backend from day one. This product has transactional workflows, scheduling constraints, and role-based permissions that fit `PostgreSQL` better than document-first stores.
- A pragmatic MVP stack is:
- `Supabase` or an equivalent Postgres-backed platform for auth, database, storage, realtime transport, and server functions.
- `Stripe Connect` for deposits, payment capture, refunds, and vendor payouts.
- `APNs` for notifications.
- Use server-side functions for all booking transitions, payment operations, idempotency checks, and authorization-sensitive message actions.
- Do not let the client finalize booking state on its own.

## Core Domain Model
- `User`
- `HostProfile`
- `VendorProfile`
- `VendorCategory`
- `VendorService`
- `VendorPackage`
- `AvailabilityWindow`
- `Event`
- `EventGuestRange`
- `BookingRequest`
- `BookingQuote`
- `Booking`
- `Conversation`
- `Message`
- `Attachment`
- `NotificationPreference`
- `Review`
- `SavedVendor`

## Search Principles
- Search must support text query, location, date, category, price band, rating, and availability-aware filtering.
- Results should feel immediate. Use pagination, prefetching, and skeleton states that do not jump.
- Keep the first version focused on a few high-value categories rather than every party service at once.
- Vendor cards should expose only the fields that influence a fast decision: image, name, category, location, price signal, rating, and next availability signal.

## Messaging Principles
- Chat is a product surface, not a secondary utility.
- Conversations must support:
- delivery state
- read state
- typing indication
- attachments
- quick replies
- quote and booking cards inline in chat
- unread count sync
- The inbox should stay useful under load. Group by event and vendor context, expose filters, and never hide booking-critical state behind ambiguous labels.

## Booking Principles
- Booking is a state machine, not a loose collection of booleans.
- Use explicit states such as:
- `draft`
- `requested`
- `vendor_reviewing`
- `quoted`
- `host_reviewing`
- `accepted`
- `deposit_pending`
- `confirmed`
- `declined`
- `cancelled`
- `completed`
- Every transition must be auditable and idempotent.
- Availability conflicts, expired quotes, duplicate deposits, and stale client state must be handled server-side.

## iOS Feature Guidance
- Use `ActivityKit` for active booking and event countdown Live Activities.
- Use `App Intents` and `App Shortcuts` for actions like opening today’s events, jumping to pending requests, or searching vendors.
- Use `TipKit` sparingly for feature discovery, especially for vendor tools and booking actions that are powerful but non-obvious.
- Use `MapKit` for vendor discovery, location previews, and event venue context.
- Consider the `Foundation Models` framework only for bounded, useful features such as summarizing long vendor threads, extracting action items from chats, or helping vendors draft polished replies. Keep it optional and never central to booking correctness.
- If payments are handled in-app, prefer `Apple Pay` wherever it meaningfully reduces checkout friction.

## Performance Rules
- Avoid network calls, heavy mapping, and filtering inside view bodies.
- Paginate vendor search and message history.
- Precompute display models for large lists.
- Cache media aggressively and size images correctly.
- Measure launch time, scroll hitching, message send latency, and booking submission latency.
- Treat placeholder shimmer, optimistic updates, and skeletons as performance UX, not cosmetic extras.

## Quality Bar
- Every non-trivial change should leave the codebase more structured than before.
- Build after meaningful edits.
- Add tests for reducers, services, booking rules, and sync edge cases.
- Prefer `Swift Testing` for new unit coverage unless an existing target already standardizes on `XCTest`.
- Add previews for major views and state variants.
- Validate dark mode, dynamic type, loading, empty, error, offline, and stale-data states.

## Delivery Plan
- The detailed roadmap lives in [`docs/implementation-plan.md`](/Users/nivensivarajah/Desktop/Plano/docs/implementation-plan.md).
- Treat that document as the execution source for phase-by-phase work.
- Before starting a major phase, confirm the phase scope, success criteria, and data contracts.

## Working Rules For Future Agents
- Read this file and the implementation plan before changing architecture.
- Make the minimum change that advances the current phase cleanly.
- Do not introduce speculative abstractions for future marketplace complexity that does not exist yet.
- Preserve the design direction: premium, quiet, fast, and trustworthy.
- When forced to choose, prioritize correctness in booking, clarity in chat, and responsiveness in search.

## Skill Usage
- Use the `swiftui-pro` skill for any meaningful SwiftUI implementation, refactor, or review work in this repository.
- Treat `swiftui-pro` as the default quality pass for view composition, modern API usage, data flow, navigation, accessibility, performance, and code hygiene.
- Use the repository-local `swiftui-pro` skill first when both a local and global copy are available.
- Use the `swift-concurrency-pro` skill for any substantial `async/await`, actor, task-cancellation, realtime sync, networking, or shared-state coordination work.
- Use the `swift-testing-pro` skill for new tests, test refactors, or test reviews, especially around booking rules, reducers, services, and sync edge cases.
- Use the `skill-installer` skill when the task is to list installable skills, install a curated skill, or install a skill from another local or remote repository.
- Use the `skill-creator` skill when creating a new skill or updating an existing skill's `SKILL.md`, references, scripts, or assets.
- When a task spans multiple areas, load only the minimal relevant set of skills and use them in the order that matches the work: UI first, concurrency second, testing last unless the task is test-only.
- Load only the skill references that match the task at hand. Do not pull in every reference file unless the work is a broad review.
- When performing a review, report only genuine issues. Organize findings by file with line references, the violated rule, and a concise before/after fix.
- When implementing SwiftUI code, follow the skill's baseline assumptions:
- target modern Apple platform APIs with iOS 26 as the primary experience
- prefer SwiftUI over UIKit unless a missing capability forces UIKit
- avoid third-party frameworks unless explicitly approved
- keep types split into focused files instead of grouping unrelated types together
- preserve feature-oriented structure over type-oriented structure
- When working on concurrency-heavy SwiftUI features, use both `swiftui-pro` and `swift-concurrency-pro`.
- When shipping a non-trivial feature or bug fix, pair the implementation skill with `swift-testing-pro` if tests are being added or updated in the same change.
