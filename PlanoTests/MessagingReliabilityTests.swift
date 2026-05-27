import Foundation
import Testing
@testable import Plano

@MainActor
struct MessagingReliabilityTests {
    @Test
    func mergeIncomingRecordsReconcilesOptimisticMessageByClientID() async throws {
        let bookingService = TestBookingService()
        let messagingService = TestMessagingService()
        let (store, _) = makeStore(
            bookingService: bookingService,
            messagingService: messagingService
        )

        let conversation = FixtureData.conversationRecord()
        let clientID = UUID()
        let optimistic = ChatMessage(
            sender: .host,
            body: "Hello there",
            sentAt: Date(timeIntervalSince1970: 100),
            status: .sending,
            clientID: clientID
        )
        store.conversations = [
            makeThread(
                from: conversation,
                messages: [optimistic],
                hasLoadedInitialMessages: true
            )
        ]

        let record = MessageRecord(
            id: UUID(),
            conversationID: conversation.id,
            senderRole: "host",
            body: "Hello there",
            kind: "text",
            createdAt: Date(timeIntervalSince1970: 101),
            status: "sent",
            clientID: clientID,
            sequenceNumber: 4
        )

        let merged = store.mergeIncomingRecords([record], attachmentsByMessage: [:], into: conversation.id)
        let thread = try #require(store.conversation(id: conversation.id, for: .host))

        #expect(merged == 1)
        #expect(thread.messages.count == 1)
        #expect(thread.messages[0].id == record.id)
        #expect(thread.messages[0].status == MessageDeliveryStatus.sent)
        #expect(thread.messages[0].sequenceNumber == 4)
    }

    @Test
    func catchUpAfterReconnectReconcilesOptimisticMessageByClientID() async throws {
        let bookingService = TestBookingService()
        let messagingService = TestMessagingService()
        let (store, _) = makeStore(
            bookingService: bookingService,
            messagingService: messagingService
        )

        let conversation = FixtureData.conversationRecord()
        let clientID = UUID()
        let optimistic = ChatMessage(
            sender: .host,
            body: "Queued hello",
            sentAt: Date(timeIntervalSince1970: 100),
            status: .sending,
            clientID: clientID
        )
        store.conversations = [
            makeThread(
                from: conversation,
                messages: [optimistic],
                hasLoadedInitialMessages: true
            )
        ]

        await messagingService.setMessages([
            MessageRecord(
                id: UUID(),
                conversationID: conversation.id,
                senderRole: "host",
                body: "Queued hello",
                kind: "text",
                createdAt: Date(timeIntervalSince1970: 101),
                status: "sent",
                clientID: clientID,
                sequenceNumber: 8
            )
        ], for: conversation.id)

        await store.catchUpAfterReconnect()

        let thread = try #require(store.conversation(id: conversation.id, for: .host))
        #expect(thread.messages.count == 1)
        #expect(thread.messages[0].status == MessageDeliveryStatus.sent)
        #expect(thread.messages[0].sequenceNumber == 8)
    }

    @Test
    func loadConversationsSeedsPreviewFromSummaryAndPreservesLoadedMessages() async throws {
        let conversation = FixtureData.conversationRecord()
        let bookingService = TestBookingService(
            conversations: [conversation],
            messagesByConversation: [
                conversation.id: [
                    MessageRecord(
                        id: UUID(),
                        conversationID: conversation.id,
                        senderRole: "vendor",
                        body: "Server preview",
                        kind: "text",
                        createdAt: Date(timeIntervalSince1970: 120),
                        status: "sent",
                        sequenceNumber: 2
                    )
                ]
            ]
        )
        let messagingService = TestMessagingService()
        let (store, _) = makeStore(
            bookingService: bookingService,
            messagingService: messagingService
        )

        let localMessage = ChatMessage(
            id: UUID(),
            sender: .host,
            body: "Draft in memory",
            sentAt: Date(timeIntervalSince1970: 119),
            status: .sending,
            clientID: UUID()
        )
        store.conversations = [
            makeThread(
                from: conversation,
                messages: [localMessage],
                hasLoadedInitialMessages: true
            )
        ]

        await store.loadConversations(for: UserRole.host)

        let thread = try #require(store.conversation(id: conversation.id, for: UserRole.host))
        let visible = try #require(store.visibleConversations(for: UserRole.host).first)

        #expect(thread.messages.count == 1)
        #expect(thread.messages[0].body == "Draft in memory")
        #expect(visible.preview == "Draft in memory")

        store.conversations = []
        await store.loadConversations(for: UserRole.host)

        let seededSummary = try #require(store.visibleConversations(for: UserRole.host).first)
        #expect(seededSummary.preview == "Server preview")
    }

    @Test
    func activeConversationKeepsUnreadCountZeroDuringRealtimeConversationUpdates() async throws {
        let conversation = FixtureData.conversationRecord()
        let bookingService = TestBookingService(conversations: [conversation])
        let messagingService = TestMessagingService()
        let (store, _) = makeStore(
            bookingService: bookingService,
            messagingService: messagingService
        )

        store.conversations = [
            makeThread(
                from: conversation,
                messages: [],
                hasLoadedInitialMessages: true,
                hostUnreadCount: 0
            )
        ]
        store.setActiveConversation(conversation.id, for: UserRole.host)

        let update = ConversationRecord(
            id: conversation.id,
            eventID: conversation.eventID,
            vendorID: conversation.vendorID,
            hostID: conversation.hostID,
            hostDisplayName: conversation.hostDisplayName,
            vendorDisplayName: conversation.vendorDisplayName,
            vendorCategory: conversation.vendorCategory,
            eventTitle: conversation.eventTitle,
            eventDateLabel: conversation.eventDateLabel,
            eventContextLine: conversation.eventContextLine,
            stage: conversation.stage,
            lastActivityAt: Date(timeIntervalSince1970: 150),
            createdAt: conversation.createdAt,
            updatedAt: Date(timeIntervalSince1970: 150),
            hostUnreadCount: 2,
            vendorUnreadCount: 0
        )

        store.handleRealtimeConversationUpdate(update)

        let thread = try #require(store.conversation(id: conversation.id, for: UserRole.host))
        #expect(thread.hostUnreadCount == 0)
    }

    private func makeStore(
        bookingService: TestBookingService,
        messagingService: TestMessagingService
    ) -> (InboxStore, SessionStore) {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let sessionStore = SessionStore(defaults: defaults)
        sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))

        let store = InboxStore(
            bookingService: bookingService,
            messagingService: messagingService,
            vendorProfileService: TestVendorProfileService(),
            sessionStore: sessionStore,
            defaults: defaults
        )
        store.configureOfflineQueue()
        store.configureRealtimeCallbacks()
        return (store, sessionStore)
    }

    private func makeThread(
        from record: ConversationRecord,
        messages: [ChatMessage],
        hasLoadedInitialMessages: Bool,
        hostUnreadCount: Int? = nil
    ) -> ConversationThread {
        ConversationThread(
            id: record.id,
            eventID: record.eventID,
            vendorID: record.vendorID,
            hostUserID: record.hostID,
            hostName: record.hostDisplayName,
            vendorName: record.vendorDisplayName,
            vendorCategory: VendorCategory.fromDatabaseValue(record.vendorCategory) ?? .entertainer,
            eventTitle: record.eventTitle ?? "Direct inquiry",
            eventDateLabel: record.eventDateLabel ?? "Date pending",
            eventContextLine: record.eventContextLine ?? "Guest count pending",
            stage: BookingStage.fromDatabaseValue(record.stage),
            messages: messages,
            lastActivityAt: record.lastActivityAt,
            hostUnreadCount: hostUnreadCount ?? (record.hostUnreadCount ?? 0),
            vendorUnreadCount: record.vendorUnreadCount ?? 0,
            hasLoadedInitialMessages: hasLoadedInitialMessages
        )
    }
}
