# Plano iOS Implementation Plan

## 1. Product Definition

### 1.1 Vision
Build a premium iPhone app for planning parties and booking vendors. The app should feel deliberately simple on the surface while handling complicated coordination underneath. The user should never experience the internal complexity of quotes, scheduling, availability, deposits, and vendor communication as chaos.

### 1.2 Core Promise
- Hosts can find the right vendor fast.
- Hosts can confidently message and request a booking without leaving the app.
- Vendors can triage leads quickly, avoid double-booking, and stay on top of upcoming events.
- The product feels trustworthy because state is always clear: who needs to act, what is pending, what is confirmed, and what happens next.

### 1.3 Primary Personas
- Host: planning a birthday, engagement, shower, wedding-adjacent event, corporate social, or private celebration.
- Vendor: decorator, caterer, DJ, photographer, planner, baker, venue, balloon artist, or rental service.
- Team member or support staff: future-only role for operational tools and dispute handling.

## 2. Product Strategy

### 2.1 MVP Scope
The MVP should not try to be the entire event industry in one release. Focus on a narrow set of categories where messaging and booking coordination matter most, such as:
- decorators
- photographers
- DJs
- caterers
- venues

### 2.2 Differentiators
- Clean, premium UX instead of cluttered marketplace patterns.
- Faster host-to-vendor conversion through stronger search and better chat.
- Vendor workflow that respects speed, queue management, and calendar reality.
- Robust booking model with visible states and fewer ambiguous handoffs.

### 2.3 Non-Goals For Phase 1
- Full web admin platform
- Complex team permissions for vendors
- Public social feed
- Deep AI automation
- Broad internationalization
- In-app contracts with full legal workflow

## 3. Experience Principles

### 3.1 Apple-Like Design Direction
- Minimal chrome
- Large, confident typography
- Strong spacing rhythm
- Materials and translucency used carefully, not everywhere
- Dense information hidden until context demands it
- Native motion and haptics to reinforce state changes
- Photos and service details presented editorially, not like a coupon grid

### 3.2 Trust Signals
- Clear pricing language
- Response time indicators
- Availability indicators
- Real review count and rating
- Booking state shown as plain language
- Payment and cancellation details visible before commitment

### 3.3 Performance Principles
- Search results should appear progressively and stay scroll-smooth.
- Chat should open instantly, preserve position, and avoid jarring reloads.
- Booking actions should acknowledge immediately even if server processing continues.
- Local drafts, pending sends, and stale state recovery should all be first-class behaviors.

## 4. Recommended Platform Decisions

### 4.1 iOS Stack
- `SwiftUI` for app UI
- `Observation` for state ownership
- `SwiftData` for local persistence, caching, and drafts
- `URLSession` with async/await for API work
- actors for sync and realtime coordination
- `ActivityKit` for live event and booking status
- `App Intents` and `App Shortcuts` for system-level actions
- `TipKit` for lightweight feature discovery
- `MapKit` for discovery and place context
- `OSLog` + `MetricKit` for instrumentation
- `Swift Testing` for new tests

### 4.2 Backend Stack
- `PostgreSQL` as the core datastore
- `Supabase` is a practical MVP option because it provides:
- auth
- relational data
- storage
- realtime events
- server-side functions
- Use `Stripe Connect` for multi-party payments and vendor payouts.
- Use server functions for all booking transitions, payment validation, and idempotency.

### 4.3 Deployment Assumption
Assumption: plan primarily for the iOS 26 SDK and current Apple design language. If later market analysis shows the need for wider OS support, create a compatibility phase rather than weakening the default implementation path now.

## 5. Information Architecture

### 5.1 Top-Level App Areas
- Home
- Search
- Inbox
- Requests for hosts, Events for vendors
- Profile

### 5.2 Role-Aware Navigation
The same app should present different default landing experiences based on role.

For hosts:
- Home shows the currently selected event and the planning shortcuts that keep discovery anchored to that brief.
- Search is a primary tab.
- Requests shows pending requests, confirmed bookings, and saved vendors for the selected event.

For vendors:
- Home becomes a dashboard with new leads, pending requests, and next upcoming event.
- Inbox remains primary.
- Events shows calendar and confirmed jobs.

## 6. Core User Flows

### 6.1 Host Discovery Flow
1. User creates or selects an event.
2. User enters location, date, guest count, and vendor category.
3. Search returns curated vendor results with filters.
4. User opens vendor profile.
5. User reviews gallery, packages, reviews, pricing signals, availability, and response behavior.
6. User starts chat or sends a booking request.

### 6.2 Host Booking Flow
1. Host sends booking request with event context.
2. Vendor reviews request.
3. Vendor replies, asks questions, or sends quote.
4. Host accepts quote.
5. Host pays deposit.
6. Booking transitions to confirmed.
7. Event workspace displays vendor, date, amount paid, remaining balance, and next steps.

### 6.3 Vendor Lead Flow
1. Vendor receives new request in dashboard and inbox.
2. Vendor sees event summary, date, budget, location, and requested service.
3. Vendor responds with message or quote.
4. Vendor tracks request under pending until host accepts or declines.
5. Confirmed work moves into upcoming events.

### 6.4 Chat-Driven Conversion Flow
1. Chat starts with structured event metadata attached.
2. Either party can send attachments, clarifications, and pricing.
3. Vendor can insert a quote card into chat.
4. Host can accept quote without leaving the conversation.
5. Booking state updates inline and in event workspace.

## 7. Domain Model

### 7.1 User and Profile
- `User`
- id
- authProviderId
- role
- displayName
- avatarURL
- phone
- email

- `HostProfile`
- userId
- preferredCity
- savedVendorIds

- `VendorProfile`
- userId
- businessName
- categories
- bio
- serviceAreas
- startingPrice
- averageResponseMinutes
- ratingAverage
- ratingCount
- portfolioAssets
- verificationState

### 7.2 Event and Booking
- `Event`
- id
- hostId
- title
- eventType
- date
- timeWindow
- location
- guestCountRange
- notes

- `BookingRequest`
- id
- eventId
- hostId
- vendorId
- requestedServiceId
- status
- createdAt
- lastActionAt

- `BookingQuote`
- id
- bookingRequestId
- lineItems
- subtotal
- fees
- depositAmount
- expirationDate
- cancellationTerms

- `Booking`
- id
- bookingRequestId
- quoteId
- status
- depositPaymentId
- remainingBalanceAmount
- confirmedAt

### 7.3 Messaging
- `Conversation`
- id
- hostId
- vendorId
- eventId
- lastMessageAt
- unreadCounts

- `Message`
- id
- conversationId
- senderId
- body
- messageType
- clientGeneratedId
- createdAt
- deliveredAt
- readAt

- `Attachment`
- id
- messageId
- storagePath
- mimeType
- dimensions

## 8. Search System

### 8.1 Search Inputs
- category
- location
- event date
- budget
- rating
- distance
- instant availability signal

### 8.2 Search Ranking
Start simple and explainable:
- exact category match
- proximity to event location
- availability overlap
- rating and review count
- response speed
- profile completeness

### 8.3 Search UX
- persistent filter bar
- high-signal cards
- fast empty states
- recent searches
- saved vendors
- map preview only when it adds value

### 8.4 Technical Approach
- Start with Postgres full-text and relational filters.
- Add geospatial support through PostGIS or equivalent.
- Move to dedicated search infrastructure only when relevance or scale clearly demands it.

## 9. Vendor Profile Design

### 9.1 Sections
- hero gallery
- business summary
- categories and packages
- pricing cues
- reviews
- availability signal
- service area
- chat or request CTA

### 9.2 Rules
- Keep the booking CTA visible without making the screen feel sales-heavy.
- Show enough information to build trust before chat starts.
- Do not bury pricing cues; vague pricing erodes confidence fast.

## 10. Messaging System

### 10.1 Required Capabilities
- realtime send and receive
- attachment upload
- delivery and read states
- typing indicator
- draft persistence
- offline queue
- quote cards
- system messages for booking transitions

### 10.2 Architecture
- Persist every message server-side.
- Use client-generated temporary IDs for optimistic sending.
- Reconcile optimistic messages against authoritative server messages.
- Keep a local message cache per conversation.
- Separate transport concerns from rendering concerns.

### 10.3 Inbox Design
Host inbox should emphasize:
- vendor name
- event context
- unread messages
- pending action

Vendor inbox should emphasize:
- lead quality
- event date
- request status
- next expected action

### 10.4 Failure Handling
- Show pending send state.
- Allow retry for failed messages.
- Preserve unsent drafts.
- Never silently drop attachments or quote cards.

## 11. Booking System

### 11.1 Booking State Machine
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

### 11.2 Booking Invariants
- Only one accepted quote can become a confirmed booking.
- Quote expiration is enforced server-side.
- Deposit creation is idempotent.
- A vendor cannot confirm over an unavailable time slot.
- State transitions are append-only in audit history.

### 11.3 Booking UX
- Every state should answer:
- what happened
- who acts next
- when the state expires or changes
- what financial commitment exists

### 11.4 Payment Strategy
- Use Stripe Connect for platform + vendor payout flows.
- Offer Apple Pay when a deposit is due.
- Store payment state on the server, not derived from client assumptions.

## 12. Event Workspace

### 12.1 Host Event Workspace
- event summary
- confirmed vendors
- pending requests
- payment milestones
- tasks and reminders
- conversation shortcuts

### 12.2 Vendor Event Workspace
- upcoming jobs
- arrival window
- host contact
- agreed package
- payment status
- special notes

### 12.3 Live State
Use Live Activities for:
- confirmed booking countdown
- upcoming event reminders
- payment due reminders when appropriate

## 13. Notifications

### 13.1 Push Notification Types
- new message
- new booking request
- quote received
- quote expiring
- booking confirmed
- event reminder
- payment reminder

### 13.2 Notification Rules
- Push only when it changes user priority, not for every low-signal event.
- Keep copy concise and actionable.
- Deep link directly to the relevant conversation, booking, or event screen.

## 14. Modern iOS Features Worth Using

### 14.1 App Intents and Shortcuts
Expose actions such as:
- open pending requests
- search nearby photographers
- view today’s events
- continue the most recent vendor conversation

### 14.2 ActivityKit
Use for short-lived, high-value states:
- quote waiting for response
- deposit pending
- event begins soon

### 14.3 TipKit
Use only for feature discovery that users may miss, for example:
- vendors learning how to send quote cards
- hosts learning how to save vendors or compare options

### 14.4 Foundation Models Framework
Use only if clearly beneficial and bounded:
- summarize long conversations
- draft cleaner vendor responses
- extract action items from message history

Do not use it for:
- booking correctness
- pricing decisions
- moderation as the only safeguard

### 14.5 MapKit
Use for:
- vendor service area
- event venue preview
- local discovery
- location confirmation flows

## 15. Security, Privacy, and Trust

### 15.1 Access Control
- All message and booking data must be role-checked server-side.
- Conversation access should be tied to event and participant membership.

### 15.2 Privacy
- Collect only data needed to facilitate booking.
- Avoid exposing private contact information before the booking stage unless intentionally supported.
- Keep AI features optional and privacy-conscious.

### 15.3 Abuse Prevention
- rate limits on message creation
- attachment scanning
- reporting and blocking flows
- suspicious booking activity checks

## 16. Analytics and Metrics

### 16.1 Product Metrics
- search-to-profile tap rate
- profile-to-chat start rate
- chat-to-booking request rate
- request-to-quote rate
- quote-to-confirmed booking rate
- vendor response time

### 16.2 Performance Metrics
- cold launch time
- search response latency
- frame drops in long lists
- chat open time
- message send latency
- booking submission latency

## 17. Testing Strategy

### 17.1 Unit Tests
- booking state transitions
- quote expiration
- availability conflict detection
- search filter logic
- message reconciliation

### 17.2 UI Tests
- onboarding
- search and filtering
- vendor profile to chat
- quote acceptance
- booking confirmation
- vendor pending request triage

### 17.3 Failure Testing
- offline message send
- duplicate payment callback
- stale quote acceptance attempt
- concurrent booking conflict

## 18. Phased Delivery Roadmap

### Phase 0: Foundation
Goals:
- remove starter-template structure
- establish app shell
- define design system
- wire auth, networking, persistence, logging, and environment configuration

Deliverables:
- role-aware app shell
- tab/navigation structure
- core models and DTO boundaries
- preview fixtures
- logging and metrics hooks

Exit criteria:
- the app can boot into distinct host and vendor placeholder experiences cleanly
- project structure supports growth

### Phase 1: Discovery MVP
Goals:
- enable event creation
- enable vendor search
- enable vendor profiles

Deliverables:
- host onboarding
- create/select event
- search screen with filters
- vendor profile screen
- save vendor flow

Exit criteria:
- a host can create an event and browse vendors relevant to that event

### Phase 2: Messaging MVP
Goals:
- enable structured conversations between host and vendor

Deliverables:
- inbox list
- conversation screen
- message sending and receiving
- draft persistence
- push for new messages

Exit criteria:
- host and vendor can reliably communicate around an event context

### Phase 3: Booking MVP
Goals:
- enable booking request, quote, acceptance, and deposit

Deliverables:
- booking request composer
- vendor request review screen
- quote card model
- deposit flow
- booking state machine UI

Exit criteria:
- a host can request a booking, receive a quote, accept it, and reach confirmed state

### Phase 4: Event Workspace
Goals:
- unify messages, bookings, and upcoming event management

Deliverables:
- host event workspace
- vendor upcoming event dashboard
- reminders
- Live Activity integration

Exit criteria:
- both roles can manage active work without relying on external tools

### Phase 5: Refinement and Scale
Goals:
- improve performance, trust, and conversion

Deliverables:
- analytics-backed search ranking improvements
- richer availability tools
- review system
- Apple Pay polish
- TipKit and Shortcuts integrations
- selective AI assistive features

Exit criteria:
- core user flows are stable, measurable, and polished

## 19. App Architecture Blueprint

### 19.1 Initial App Layers
- `AppEnvironment`: creates shared services and runtime dependencies.
- `SessionStore`: owns auth session, current role, and top-level user context.
- `AppRouter`: owns root tab selection and deep link routing.
- Feature stores: one `@Observable` store per major feature surface.
- Service layer: networking, search, chat, booking, payments, notifications, and media.
- Data layer: DTO mapping, local cache models, persistence adapters, and sync helpers.

### 19.2 Suggested Feature Stores
- `HomeStore`
- `SearchStore`
- `VendorProfileStore`
- `InboxStore`
- `ConversationStore`
- `BookingRequestStore`
- `EventWorkspaceStore`
- `VendorDashboardStore`

### 19.3 Suggested Service Boundaries
- `AuthService`
- `EventService`
- `VendorSearchService`
- `ConversationService`
- `RealtimeMessagingService`
- `BookingService`
- `PaymentsService`
- `NotificationsService`
- `MediaService`
- `LocationService`

### 19.4 Local Persistence Strategy
Use `SwiftData` only for data that materially improves perceived speed or resilience:
- cached current user profile
- selected event context
- recent searches
- saved vendor snapshots
- conversation drafts
- cached message windows
- attachment upload queue

Do not rely on local persistence as the final source for:
- booking confirmation truth
- payment status
- vendor availability truth
- unread count truth across devices

### 19.5 Realtime Strategy
- Use REST or RPC-style calls for fetch and mutate flows.
- Use a realtime channel or WebSocket for message delivery, typing, unread count deltas, and booking state updates.
- Treat realtime events as deltas that update local state rather than a replacement for fetch APIs.
- Re-fetch the authoritative record after critical transitions such as quote acceptance or deposit completion.

## 20. MVP API Surface

### 20.1 Host-Facing Endpoints
- `POST /events`
- `GET /events`
- `GET /vendors/search`
- `GET /vendors/:id`
- `POST /saved-vendors`
- `DELETE /saved-vendors/:vendorId`
- `POST /conversations`
- `GET /conversations`
- `GET /conversations/:id/messages`
- `POST /messages`
- `POST /booking-requests`
- `POST /quotes/:id/accept`
- `POST /payments/deposits`

### 20.2 Vendor-Facing Endpoints
- `GET /vendor/dashboard`
- `GET /vendor/requests/pending`
- `POST /booking-requests/:id/respond`
- `POST /quotes`
- `PATCH /availability`
- `GET /vendor/events/upcoming`

### 20.3 Event Contracts
Every mutate endpoint should return:
- the updated resource
- a server timestamp
- an idempotency-safe request identifier where applicable
- next action hints when the workflow is stateful

## 21. Design System Starter

### 21.1 Tokens
- color roles, not raw colors
- spacing scale
- corner radius scale
- elevation or shadow levels
- typography styles
- motion durations and curves
- haptic intent mapping

### 21.2 Reusable Components
- app background container
- large title header
- vendor result card
- section header
- empty state
- loading skeleton
- chat bubble
- inline quote card
- status badge
- primary action bar

### 21.3 Visual Direction
- warm neutral palette with restrained accent color
- large-format vendor imagery
- generous whitespace
- strong card surfaces with subtle depth
- consistent iconography, ideally SF Symbols first

## 22. Phase 0 Detailed Checklist

### 22.1 Replace Starter App Structure
- remove the sample `Item` model and list-based starter UI
- create the five-tab shell
- create host and vendor role switch support using local mock state
- add `NavigationStack` per major tab where needed

### 22.2 Create Core Infrastructure
- `AppEnvironment`
- `SessionStore`
- `AppRouter`
- shared `OSLog` definitions
- networking client and API error model
- image loading strategy

### 22.3 Create Initial Feature Skeletons
- Home placeholder
- Search placeholder
- Inbox placeholder
- Events placeholder
- Profile placeholder
- vendor dashboard variant for role-aware home

### 22.4 Create Preview and Mock Data Strategy
- static mock vendors
- mock event
- mock conversation
- mock pending request
- preview states for empty, loading, populated, and error variants

### 22.5 Add Quality Guardrails
- unit test target if absent
- first smoke UI test
- build verification step
- lint or formatting choice if the team wants one

## 23. Immediate Build Order

Start with this exact order:
1. Replace starter architecture with app shell and feature folders.
2. Establish design tokens and reusable surfaces.
3. Create host and vendor role switching with mock data.
4. Build event creation and event selection.
5. Build vendor search and vendor profile.
6. Build inbox and conversation infrastructure.
7. Build booking request and quote flow.
8. Add payments and booking confirmation.
9. Build event workspaces.
10. Add Live Activities, App Intents, TipKit, and bounded AI helpers.

## 24. Next Implementation Recommendation
The best first implementation phase is `Phase 0: Foundation`.

That should include:
- removing the starter `Item` model and sample list UI
- creating a real tab shell
- adding a shared design system
- introducing mock host and vendor data
- stubbing the five top-level app areas
- setting up the first feature boundaries so later phases do not require a rewrite

## 25. Official Apple References
- What’s new in iOS 26: https://developer.apple.com/ios/whats-new/
- SwiftUI overview: https://developer.apple.com/swiftui/
- ActivityKit: https://developer.apple.com/documentation/ActivityKit/
- Displaying live data with Live Activities: https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities
- App Intents: https://developer.apple.com/documentation/AppIntents/app-intents
- App Shortcuts: https://developer.apple.com/documentation/AppIntents/app-shortcuts
- TipKit: https://developer.apple.com/documentation/tipkit/
- SwiftData ModelContainer: https://developer.apple.com/documentation/swiftdata/modelcontainer
- MapKit overview: https://developer.apple.com/maps/
- Apple Pay planning: https://developer.apple.com/apple-pay/get-started/
- Wallet Orders: https://developer.apple.com/documentation/WalletOrders
