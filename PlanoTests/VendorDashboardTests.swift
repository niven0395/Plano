import Foundation
import Testing
@testable import Plano

struct VendorDashboardTests {
    @Test
    func bookingStagesExposeVendorActionLabels() {
        #expect(BookingStage.requested.vendorActionLabel == "Review request")
        #expect(BookingStage.requested.requiresVendorAction)

        #expect(BookingStage.accepted.vendorActionLabel == "Request payment")
        #expect(BookingStage.accepted.requiresVendorAction)

        #expect(BookingStage.paymentRequested.vendorActionLabel == "Awaiting payment")
        #expect(BookingStage.paymentRequested.requiresVendorAction == false)
    }

    @Test
    @MainActor
    func vendorDashboardPrioritizesVendorActionBeforeWaitingStates() async {
        await withIsolatedDefaults { defaults in
            let eventDates = [3, 5, 10, 12, 4].compactMap {
                Calendar.current.date(byAdding: .day, value: $0, to: .now)
            }

            let events = [
                makeEvent(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000E101") ?? UUID(),
                    title: "Host approval pending",
                    date: eventDates[0],
                    guestCount: 50
                ),
                makeEvent(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000E102") ?? UUID(),
                    title: "Quote next",
                    date: eventDates[1],
                    guestCount: 25
                ),
                makeEvent(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000E103") ?? UUID(),
                    title: "Fresh request",
                    date: eventDates[2],
                    guestCount: 90
                ),
                makeEvent(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000E104") ?? UUID(),
                    title: "Confirm details",
                    date: eventDates[3],
                    guestCount: 50
                ),
                makeEvent(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000E105") ?? UUID(),
                    title: "Host reviewing quote",
                    date: eventDates[4],
                    guestCount: 25
                ),
            ]

            let conversations = [
                conversationRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C101") ?? UUID(),
                    hostName: "Maya Chen",
                    event: events[0],
                    stage: .paymentRequested
                ),
                conversationRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C102") ?? UUID(),
                    hostName: "Naomi Singh",
                    event: events[1],
                    stage: .requested
                ),
                conversationRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C103") ?? UUID(),
                    hostName: "Jordan Brooks",
                    event: events[2],
                    stage: .requested
                ),
                conversationRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C104") ?? UUID(),
                    hostName: "Avery Hall",
                    event: events[3],
                    stage: .accepted
                ),
                conversationRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C105") ?? UUID(),
                    hostName: "Lena Park",
                    event: events[4],
                    stage: .paymentRequested
                ),
            ]

            let bookingService = TestBookingService(conversations: conversations)
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAuthenticatedSession(FixtureData.vendorSession, preferredRole: .vendor)

            let inboxStore = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )
            inboxStore.conversations = conversations.map { makeThread(from: $0) }

            let store = VendorDashboardStore(
                bookingService: bookingService,
                sessionStore: sessionStore,
                inboxStore: inboxStore
            )

            await store.load()

            #expect(store.loadingState == .loaded)
            #expect(store.leadQueue.map(\.counterpartName) == [
                "Naomi Singh",
                "Jordan Brooks",
                "Avery Hall",
                "Maya Chen",
                "Lena Park",
            ])
            #expect(store.leadQueue.prefix(3).allSatisfy { $0.stage.requiresVendorAction })
            #expect(store.leadQueue.dropFirst(3).allSatisfy { $0.stage.requiresVendorAction == false })
        }
    }

    @Test
    @MainActor
    func vendorDashboardExcludesDraftConversationsFromLeadQueue() async {
        await withIsolatedDefaults { defaults in
            let upcomingEvent = makeEvent(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000E201") ?? UUID(),
                title: "Lead-ready event",
                date: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
                guestCount: 40
            )

            let conversations = [
                conversationRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C201") ?? UUID(),
                    hostName: "Draft-only thread",
                    event: upcomingEvent,
                    stage: .active
                ),
                conversationRecord(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000C202") ?? UUID(),
                    hostName: "Structured lead",
                    event: upcomingEvent,
                    stage: .requested
                ),
            ]

            let bookingService = TestBookingService(conversations: conversations)
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAuthenticatedSession(FixtureData.vendorSession, preferredRole: .vendor)

            let inboxStore = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )
            inboxStore.conversations = conversations.map { makeThread(from: $0) }

            let store = VendorDashboardStore(
                bookingService: bookingService,
                sessionStore: sessionStore,
                inboxStore: inboxStore
            )

            await store.load()

            #expect(store.leadQueue.count == 1)
            #expect(store.leadQueue.first?.counterpartName == "Structured lead")
            #expect(store.leadQueue.first?.stage == .requested)
        }
    }

    private func makeThread(from record: ConversationRecord) -> ConversationThread {
        let stage = BookingStage.fromDatabaseValue(record.stage)
        return ConversationThread(
            id: record.id,
            eventID: record.eventID,
            vendorID: record.vendorID,
            hostUserID: record.hostID,
            hostName: record.hostDisplayName,
            vendorName: record.vendorDisplayName,
            vendorCategory: VendorCategory(rawValue: record.vendorCategory) ?? .entertainer,
            eventTitle: record.eventTitle ?? "Direct inquiry",
            eventDateLabel: record.eventDateLabel ?? "Date pending",
            eventContextLine: record.eventContextLine ?? "Guest count pending",
            stage: stage,
            messages: [],
            lastActivityAt: record.lastActivityAt,
            hostUnreadCount: record.hostUnreadCount ?? 0,
            vendorUnreadCount: record.vendorUnreadCount ?? 0,
            hasLoadedInitialMessages: false,
            hasOlderMessages: false
        )
    }

    private func conversationRecord(
        id: UUID,
        hostName: String,
        event: FixtureData.EventFixture,
        stage: BookingStage
    ) -> ConversationRecord {
        ConversationRecord(
            id: id,
            eventID: event.id,
            vendorID: FixtureData.vendorID,
            hostID: FixtureData.hostID,
            hostDisplayName: hostName,
            vendorDisplayName: "Studio Petal",
            vendorCategory: VendorCategory.decorator.rawValue,
            eventTitle: event.title,
            eventDateLabel: event.formattedDate,
            eventContextLine: event.contextLine,
            stage: stage.rawValue,
            lastActivityAt: .now,
            createdAt: .now,
            updatedAt: .now,
            hostUnreadCount: nil,
            vendorUnreadCount: nil
        )
    }

    private func makeEvent(
        id: UUID,
        title: String,
        date: Date,
        guestCount: Int
    ) -> FixtureData.EventFixture {
        FixtureData.EventFixture(
            id: id,
            title: title,
            date: date,
            venue: "Maison North",
            city: "Toronto",
            guestCount: guestCount
        )
    }

    @MainActor
    private func withIsolatedDefaults(_ body: (UserDefaults) async -> Void) async {
        let suiteName = "PlanoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        await body(defaults)
    }
}
