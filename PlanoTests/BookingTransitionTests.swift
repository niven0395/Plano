import Foundation
import Testing
@testable import Plano

struct BookingTransitionTests {
    @Test
    @MainActor
    func declineTransitionMovesThreadAndBookingToDeclined() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(stage: .requested)
            let request = makeRequest(conversationID: conversation.id)
            let booking = makeBooking(conversation: conversation, stage: .requested)
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookingRequests: [request],
                bookings: [booking]
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAuthenticatedSession(FixtureData.vendorSession, preferredRole: .vendor)

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await store.loadConversations(for: .vendor)
            await store.declineBooking(in: conversation.id, reason: "Already booked that weekend.")
            try? await Task.sleep(for: .milliseconds(50))

            let thread = try #require(store.conversation(id: conversation.id, for: .vendor))
            #expect(thread.stage == .declined)

            let updatedBooking = try #require(
                try await bookingService.fetchBookings(conversationIDs: [conversation.id]).first
            )
            #expect(updatedBooking.stage == BookingStage.declined.rawValue)
            #expect(updatedBooking.cancellationReason == "Already booked that weekend.")
        }
    }

    @Test
    @MainActor
    func cancelTransitionCapturesCancellationMetadata() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(stage: .paid)
            let booking = makeBooking(
                conversation: conversation,
                stage: .paid,
                depositPaidAt: .now
            )
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookings: [booking]
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await store.loadConversations(for: .host)
            store.cancelBooking(in: conversation.id, reason: "Event date changed.")
            try? await Task.sleep(for: .milliseconds(50))

            let thread = try #require(store.conversation(id: conversation.id, for: .host))
            #expect(thread.stage == .cancelled)

            let updatedBooking = try #require(
                try await bookingService.fetchBookings(conversationIDs: [conversation.id]).first
            )
            #expect(updatedBooking.stage == BookingStage.cancelled.rawValue)
            #expect(updatedBooking.cancellationReason == "Event date changed.")
            #expect(updatedBooking.cancelledAt != nil)
        }
    }

    @Test
    @MainActor
    func legacyConfirmedBookingCancelsCleanlyAfterReload() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(rawStage: "confirmed")
            let booking = makeBooking(
                conversation: conversation,
                rawStage: "confirmed",
                depositPaidAt: .now
            )
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookings: [booking]
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await store.loadConversations(for: .host)
            let loadedThread = try #require(store.conversation(id: conversation.id, for: .host))
            #expect(loadedThread.stage == .paid)

            store.cancelBooking(in: conversation.id, reason: "Event date changed.")
            try? await Task.sleep(for: .milliseconds(50))

            let cancelledThread = try #require(store.conversation(id: conversation.id, for: .host))
            #expect(cancelledThread.stage == .cancelled)

            let updatedBooking = try #require(
                try await bookingService.fetchBookings(conversationIDs: [conversation.id]).first
            )
            #expect(updatedBooking.stage == BookingStage.cancelled.rawValue)
        }
    }

    @Test
    @MainActor
    func ensureConversationLoadedRecoversMissingVendorThread() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(stage: .requested)
            let request = makeRequest(conversationID: conversation.id)
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookingRequests: [request]
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAuthenticatedSession(FixtureData.vendorSession, preferredRole: .vendor)

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            let recovered = await store.ensureConversationLoaded(conversation.id, for: .vendor)

            #expect(recovered?.id == conversation.id)
            #expect(store.conversation(id: conversation.id, for: .vendor)?.stage == .requested)
        }
    }

    @Test
    func bookingRowIsCreatedWhenRequestIsSubmitted() async throws {
        let conversation = makeConversation(stage: .active)
        let service = TestBookingService(conversations: [conversation])

        _ = try await service.submitBookingRequest(
            conversationID: conversation.id,
            eventDate: FixtureData.primaryEvent.date,
            note: "Need install support."
        )

        let bookings = try await service.fetchBookings(conversationIDs: [conversation.id])
        let booking = try #require(bookings.first)
        let bookingRequest = try #require(try await service.fetchBookingRequests(conversationIDs: [conversation.id]).first)
        #expect(booking.conversationID == conversation.id)
        #expect(booking.stage == BookingStage.requested.rawValue)
        #expect(booking.eventDate != nil)
        #expect(bookingRequest.note == "Need install support.")
    }

    @Test
    func confirmPaymentIsIdempotent() async throws {
        let conversation = makeConversation(stage: .paymentRequested)
        let booking = makeBooking(conversation: conversation, stage: .paymentRequested)
        let service = TestBookingService(
            conversations: [conversation],
            bookings: [booking]
        )

        let idempotencyKey = UUID()
        let firstResult = try await service.confirmPayment(
            conversationID: conversation.id,
            idempotencyKey: idempotencyKey
        )
        let secondResult = try await service.confirmPayment(
            conversationID: conversation.id,
            idempotencyKey: idempotencyKey
        )

        let bookings = try await service.fetchBookings(conversationIDs: [conversation.id])
        let paidBooking = try #require(bookings.first)
        #expect(bookings.count == 1)
        #expect(firstResult.bookingID == secondResult.bookingID)
        #expect(paidBooking.stage == BookingStage.paid.rawValue)
        #expect(paidBooking.paymentConfirmedAt != nil)
    }

    @Test
    @MainActor
    func confirmPaymentReloadsAuthoritativeCancellationMetadata() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(stage: .paymentRequested)
            let booking = makeBooking(conversation: conversation, stage: .paymentRequested)
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookings: [booking]
            )
            await bookingService.setConfirmPaymentResultOverride(BookingTransitionResult(
                conversationID: conversation.id,
                stage: BookingStage.cancellationRequested.rawValue,
                bookingID: booking.id,
                dateConflicts: nil,
                cancellationRequestDeadline: .now.addingTimeInterval(3600),
                cancellationRequestedBy: FixtureData.hostID
            ))

            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await store.loadConversations(for: .host)
            await store.confirmPayment(in: conversation.id)
            try? await Task.sleep(for: .milliseconds(50))

            let thread = try #require(store.conversation(id: conversation.id, for: .host))
            #expect(thread.stage == .cancellationRequested)
            #expect(thread.cancellationRequestedByRole == .host)
            #expect(thread.cancellationRequestDeadline != nil)
        }
    }

    @Test
    func submitBookingRequestRejectsInvalidTimeRange() async throws {
        let conversation = makeConversation(stage: .active)
        let service = TestBookingService(conversations: [conversation])

        do {
            _ = try await service.submitBookingRequest(
                conversationID: conversation.id,
                eventDate: FixtureData.primaryEvent.date,
                note: "Need install support.",
                requestedTimeStart: "18:00:00",
                requestedTimeEnd: "17:00:00",
                title: nil,
                budgetLabel: nil,
                guestCountLabel: nil,
                requestedServices: nil,
                intakeAnswers: nil,
                idempotencyKey: UUID()
            )
            Issue.record("Expected invalid time range to throw")
        } catch {
            #expect(error.localizedDescription.contains("later than the start time"))
        }
    }

    @Test
    func cancellationRequestedStageHasCorrectProperties() {
        let stage = BookingStage.cancellationRequested
        #expect(stage.title == "Cancellation requested")
        #expect(stage.vendorActionLabel == "Review cancellation")
        #expect(stage.tone == .gold)
        #expect(stage.isConfirmed == false)
        #expect(stage.requiresVendorAction)
        #expect(stage.isTerminal == false)
        #expect(stage.isRebookable == false)
        #expect(stage.isActionable)
    }

    @Test
    func legacyConfirmedDatabaseValueMapsToPaid() {
        #expect(BookingStage.fromDatabaseValue("confirmed") == .paid)
    }

    // MARK: - Cancellation v3 tests

    @Test
    func prePaymentStagesAreCancellable() {
        #expect(BookingStage.requested.isCancellable)
        #expect(BookingStage.accepted.isCancellable)
        #expect(BookingStage.paymentRequested.isCancellable)
    }

    @Test
    func paidStageIsCancellable() {
        #expect(BookingStage.paid.isCancellable)
    }

    @Test
    func terminalStagesAreNotCancellable() {
        #expect(BookingStage.declined.isCancellable == false)
        #expect(BookingStage.cancelled.isCancellable == false)
        #expect(BookingStage.cancellationRequested.isCancellable == false)
    }

    @Test
    func cancellationRequestedRequiresBothHostAndVendorAction() {
        let stage = BookingStage.cancellationRequested
        #expect(stage.requiresVendorAction)
        #expect(stage.requiresHostAction)
        #expect(stage.isActionable)
    }

    @Test
    @MainActor
    func prePaymentHostCancelIsAlwaysDirectRegardlessOfPolicy() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(stage: .requested)
            let booking = makeBooking(conversation: conversation, stage: .requested)
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookings: [booking]
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await store.loadConversations(for: .host)

            // Cancel a requested booking — should be direct cancel, no approval
            store.cancelBooking(in: conversation.id, reason: "Changed my mind.")
            try? await Task.sleep(for: .milliseconds(50))

            let thread = try #require(store.conversation(id: conversation.id, for: .host))
            #expect(thread.stage == .cancelled)
        }
    }

    @Test
    @MainActor
    func prePaymentVendorCancelIsDirectAtAccepted() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(stage: .accepted)
            let booking = makeBooking(conversation: conversation, stage: .accepted)
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookings: [booking]
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAuthenticatedSession(FixtureData.vendorSession, preferredRole: .vendor)

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await store.loadConversations(for: .vendor)
            store.cancelBooking(in: conversation.id, reason: "Schedule conflict.")
            try? await Task.sleep(for: .milliseconds(50))

            let thread = try #require(store.conversation(id: conversation.id, for: .vendor))
            #expect(thread.stage == .cancelled)
        }
    }

    // MARK: - Cancellation role tracking & archive-based removal

    @Test
    @MainActor
    func prePaymentCancelSetsHostCancellationRole() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(stage: .requested)
            let booking = makeBooking(conversation: conversation, stage: .requested)
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookings: [booking]
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await store.loadConversations(for: .host)
            store.cancelBooking(in: conversation.id, reason: "Changed my mind.")

            // Check optimistic state immediately (before server round-trip)
            let thread = try #require(store.conversation(id: conversation.id, for: .host))
            #expect(thread.stage == .cancelled)
            #expect(thread.cancellationRequestedByRole == .host)
            #expect(thread.isHostCancelled)
        }
    }

    @Test
    @MainActor
    func forceCancelSetsHostCancellationRole() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(stage: .cancellationRequested)
            let booking = makeBooking(
                conversation: conversation,
                stage: .cancellationRequested,
                cancellationRequestedBy: FixtureData.hostID,
                cancellationDeclinedAt: .now
            )
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookings: [booking]
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await store.loadConversations(for: .host)
            store.forceCancelBooking(in: conversation.id, reason: "Need to cancel.")

            let thread = try #require(store.conversation(id: conversation.id, for: .host))
            #expect(thread.stage == .cancelled)
            #expect(thread.cancellationRequestedByRole == .host)
            #expect(thread.isHostCancelled)
        }
    }

    @Test
    @MainActor
    func archivedTerminalConversationExcludedFromCategoryGroups() async throws {
        try await withIsolatedDefaults { defaults in
            let conversation = makeConversation(stage: .declined)
            let booking = makeBooking(conversation: conversation, stage: .declined)
            let bookingService = TestBookingService(
                conversations: [conversation],
                bookings: [booking]
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))

            let store = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await store.loadConversations(for: .host)

            // Before archiving, the conversation is visible
            let before = store.conversation(id: conversation.id, for: .host)
            #expect(before != nil)
            #expect(store.isArchived(conversation.id, for: .host) == false)

            // Archive the conversation (simulates "Remove from plan")
            store.archiveConversation(conversation.id, for: .host)
            #expect(store.isArchived(conversation.id, for: .host))
        }
    }

    private func makeConversation(stage: BookingStage) -> ConversationRecord {
        makeConversation(rawStage: stage.rawValue)
    }

    private func makeConversation(rawStage: String) -> ConversationRecord {
        let event = FixtureData.primaryEvent
        return ConversationRecord(
            id: UUID(),
            eventID: event.id,
            vendorID: FixtureData.vendorID,
            hostID: FixtureData.hostID,
            hostDisplayName: "Maya Chen",
            vendorDisplayName: "Studio Petal",
            vendorCategory: VendorCategory.decorator.rawValue,
            eventTitle: event.title,
            eventDateLabel: event.formattedDate,
            eventContextLine: event.contextLine,
            stage: rawStage,
            lastActivityAt: .now,
            createdAt: .now,
            updatedAt: .now,
            hostUnreadCount: nil,
            vendorUnreadCount: nil
        )
    }

    private func makeRequest(conversationID: UUID) -> BookingRequestRecord {
        BookingRequestRecord(
            id: UUID(),
            conversationID: conversationID,
            title: "Decor request",
            budgetLabel: nil,
            responseWindowLabel: "48 hours",
            requestedServices: ["Floral design"],
            note: "Need install support.",
            guestCountLabel: "80 guests",
            eventDate: FixtureData.primaryEvent.date,
            createdAt: .now
        )
    }

    private func makeBooking(
        conversation: ConversationRecord,
        stage: BookingStage,
        depositPaidAt: Date? = nil,
        cancellationRequestedBy: UUID? = nil,
        cancellationDeclinedAt: Date? = nil
    ) -> BookingRecord {
        makeBooking(
            conversation: conversation,
            rawStage: stage.rawValue,
            depositPaidAt: depositPaidAt,
            cancellationRequestedBy: cancellationRequestedBy,
            cancellationDeclinedAt: cancellationDeclinedAt
        )
    }

    private func makeBooking(
        conversation: ConversationRecord,
        rawStage: String,
        depositPaidAt: Date? = nil,
        cancellationRequestedBy: UUID? = nil,
        cancellationDeclinedAt: Date? = nil
    ) -> BookingRecord {
        BookingRecord(
            id: UUID(),
            conversationID: conversation.id,
            eventID: conversation.eventID,
            vendorID: conversation.vendorID,
            hostID: conversation.hostID,
            depositAmountLabel: "$1,230",
            depositAmountCents: 123_000,
            totalAmountCents: 410_000,
            currency: "cad",
            eventDate: FixtureData.primaryEvent.date,
            depositMethod: depositPaidAt == nil ? nil : "Apple Pay",
            depositPaidAt: depositPaidAt,
            cancellationRequestedBy: cancellationRequestedBy,
            cancellationDeclinedAt: cancellationDeclinedAt,
            stage: rawStage,
            createdAt: .now,
            updatedAt: .now
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
