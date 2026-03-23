import Foundation
import Testing
@testable import Plano

struct RequestsStoreTests {
    @Test
    @MainActor
    func requestsStoreSplitsPendingAndConfirmedVendorsForTheSelectedEvent() async throws {
        try await withIsolatedDefaults { defaults in
            let planner = HostPlanningStore(
                eventService: TestEventService(events: FixtureData.events),
                vendorSearchService: TestVendorSearchService(vendorProfiles: FixtureData.vendorProfiles),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let inboxStore = InboxStore(
                bookingService: TestBookingService(),
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: SessionStore(defaults: defaults),
                defaults: defaults
            )
            let store = RequestsStore(planner: planner, inboxStore: inboxStore)

            await planner.load()

            let selectedEvent = try #require(planner.events.first)
            let confirmedEvent = try #require(planner.events.last)

            inboxStore.conversations = [
                makeThread(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C701") ?? UUID(),
                    event: selectedEvent,
                    vendor: FixtureData.vendorProfiles[0],
                    stage: .accepted
                ),
                makeThread(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C702") ?? UUID(),
                    event: selectedEvent,
                    vendor: FixtureData.vendorProfiles[1],
                    stage: .paid
                ),
                makeThread(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C703") ?? UUID(),
                    event: confirmedEvent,
                    vendor: FixtureData.vendorProfiles[2],
                    stage: .requested
                ),
            ]

            #expect(store.pendingRequests.count == 1)
            #expect(store.pendingRequests.first?.vendorName == "Studio Petal")
            #expect(store.pendingRequests.first?.primaryActionTitle == "Review quote")

            #expect(store.confirmedRequests.count == 1)
            #expect(store.confirmedRequests.first?.vendorName == "North Frame")
            #expect(store.confirmedRequests.first?.primaryDestination == .workspace(selectedEvent.id))
        }
    }

    @Test
    @MainActor
    func requestsStoreReScopesRequestsWhenTheSelectedEventChanges() async throws {
        try await withIsolatedDefaults { defaults in
            let planner = HostPlanningStore(
                eventService: TestEventService(events: FixtureData.events),
                vendorSearchService: TestVendorSearchService(vendorProfiles: FixtureData.vendorProfiles),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let inboxStore = InboxStore(
                bookingService: TestBookingService(),
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: SessionStore(defaults: defaults),
                defaults: defaults
            )
            let store = RequestsStore(planner: planner, inboxStore: inboxStore)

            await planner.load()

            let firstEvent = try #require(planner.events.first)
            let secondEvent = try #require(planner.events.last)

            inboxStore.conversations = [
                makeThread(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C711") ?? UUID(),
                    event: firstEvent,
                    vendor: FixtureData.vendorProfiles[0],
                    stage: .requested
                ),
                makeThread(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C712") ?? UUID(),
                    event: secondEvent,
                    vendor: FixtureData.vendorProfiles[1],
                    stage: .paymentRequested
                ),
            ]

            #expect(store.activeEvent.id == firstEvent.id)
            #expect(store.pendingRequests.count == 1)
            #expect(store.pendingRequests.first?.vendorName == "Studio Petal")

            store.selectEvent(secondEvent.id)

            #expect(store.activeEvent.id == secondEvent.id)
            #expect(store.pendingRequests.count == 1)
            #expect(store.pendingRequests.first?.vendorName == "North Frame")
            #expect(store.pendingRequests.first?.primaryActionTitle == "Pay deposit")
        }
    }

    private func makeThread(
        id: UUID,
        event: PartyEvent,
        vendor: VendorProfile,
        stage: BookingStage
    ) -> ConversationThread {
        ConversationThread(
            id: id,
            eventID: event.id,
            eventDate: event.date,
            vendorID: vendor.id,
            hostUserID: FixtureData.hostID,
            hostName: "Maya Chen",
            vendorName: vendor.businessName,
            vendorCategory: vendor.category,
            eventTitle: event.title,
            eventDateLabel: event.formattedDate,
            eventContextLine: event.contextLine,
            stage: stage,
            paymentRequest: stage == .paymentRequested || stage == .paid
                ? PaymentRequest(
                    amountCents: 100_000,
                    amountLabel: "$1,000",
                    note: "Quote is ready to review.",
                    status: stage == .paid ? .paid : .pending
                )
                : nil,
            messages: [
                ChatMessage(
                    sender: .vendor,
                    body: "Latest thread update",
                    sentAt: .now
                ),
            ],
            lastActivityAt: .now,
            hostUnreadCount: 0,
            vendorUnreadCount: 0
        )
    }

    @MainActor
    private func withIsolatedDefaults(_ body: (UserDefaults) async throws -> Void) async rethrows {
        let suiteName = "PlanoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try await body(defaults)
    }
}
