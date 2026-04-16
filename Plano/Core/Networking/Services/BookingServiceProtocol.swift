import Foundation

protocol BookingServiceProtocol: Sendable {
    func fetchConversations(hostID: UUID) async throws -> [ConversationRecord]
    func fetchVendorConversations(vendorID: UUID) async throws -> [ConversationRecord]
    func createConversation(vendorID: UUID, hostID: UUID) async throws -> ConversationRecord

    func fetchMessages(conversationID: UUID) async throws -> [MessageRecord]
    func sendMessage(conversationID: UUID, body: String, kind: String, senderRole: String) async throws -> MessageRecord

    func fetchBookingRequests(conversationIDs: [UUID]) async throws -> [BookingRequestRecord]
    func fetchBookings(conversationIDs: [UUID]) async throws -> [BookingRecord]
    func fetchHostBookings(hostID: UUID) async throws -> [BookingRecord]
    func fetchVendorBookings(vendorID: UUID) async throws -> [BookingRecord]

    func submitBookingRequest(conversationID: UUID, eventDate: Date, note: String, requestedTimeStart: String?, requestedTimeEnd: String?, title: String?, budgetLabel: String?, guestCountLabel: String?, requestedServices: [String]?, intakeAnswers: [LeadIntakeAnswer]?, idempotencyKey: UUID) async throws -> BookingTransitionResult
    func acceptBooking(conversationID: UUID, idempotencyKey: UUID) async throws -> BookingTransitionResult
    func declineBooking(conversationID: UUID, reason: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult
    func requestPayment(conversationID: UUID, amountCents: Int, note: String?, paymentType: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult
    func confirmPayment(conversationID: UUID, idempotencyKey: UUID) async throws -> BookingTransitionResult
    func vendorConfirmPayment(conversationID: UUID, idempotencyKey: UUID) async throws -> BookingTransitionResult
    func cancelBooking(conversationID: UUID, reason: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult
    func respondToCancellationRequest(conversationID: UUID, approved: Bool, reason: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult
    func forceCancelBooking(conversationID: UUID, reason: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult

    func checkVendorDateConflicts(vendorID: UUID, eventDate: Date) async throws -> [DateConflict]
    func createConversationServer(vendorID: UUID) async throws -> ConversationRecord
    func fetchConversationSummaries(role: String) async throws -> [ConversationSummaryRecord]

    func fetchVendorNote(conversationID: UUID) async throws -> String?
    func saveVendorNote(conversationID: UUID, content: String) async throws
}

extension BookingServiceProtocol {
    func submitBookingRequest(conversationID: UUID, eventDate: Date, note: String, idempotencyKey: UUID = UUID()) async throws -> BookingTransitionResult {
        try await submitBookingRequest(conversationID: conversationID, eventDate: eventDate, note: note, requestedTimeStart: nil, requestedTimeEnd: nil, title: nil, budgetLabel: nil, guestCountLabel: nil, requestedServices: nil, intakeAnswers: nil, idempotencyKey: idempotencyKey)
    }

    func submitBookingRequest(conversationID: UUID, eventDate: Date, note: String, requestedTimeStart: String?, requestedTimeEnd: String?, idempotencyKey: UUID = UUID()) async throws -> BookingTransitionResult {
        try await submitBookingRequest(conversationID: conversationID, eventDate: eventDate, note: note, requestedTimeStart: requestedTimeStart, requestedTimeEnd: requestedTimeEnd, title: nil, budgetLabel: nil, guestCountLabel: nil, requestedServices: nil, intakeAnswers: nil, idempotencyKey: idempotencyKey)
    }
}
