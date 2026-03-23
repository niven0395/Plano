import Foundation

protocol BookingServiceProtocol: Sendable {
    func fetchConversations(hostID: UUID) async throws -> [ConversationRecord]
    func fetchVendorConversations(vendorID: UUID) async throws -> [ConversationRecord]
    func createConversation(vendorID: UUID, hostID: UUID, eventID: UUID?) async throws -> ConversationRecord

    func fetchMessages(conversationID: UUID) async throws -> [MessageRecord]
    func sendMessage(conversationID: UUID, body: String, kind: String, senderRole: String) async throws -> MessageRecord

    func fetchBookingRequests(conversationIDs: [UUID]) async throws -> [BookingRequestRecord]
    func fetchBookings(conversationIDs: [UUID]) async throws -> [BookingRecord]
    func fetchHostBookings(hostID: UUID) async throws -> [BookingRecord]
    func fetchVendorBookings(vendorID: UUID) async throws -> [BookingRecord]

    func submitBookingRequest(conversationID: UUID, eventDate: Date, note: String, requestedTimeStart: String?, requestedTimeEnd: String?, title: String?, budgetLabel: String?, guestCountLabel: String?, requestedServices: [String]?) async throws -> BookingTransitionResult
    func acceptBooking(conversationID: UUID) async throws -> BookingTransitionResult
    func declineBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult
    func requestPayment(conversationID: UUID, amountCents: Int, note: String?, paymentType: String?) async throws -> BookingTransitionResult
    func confirmPayment(conversationID: UUID) async throws -> BookingTransitionResult
    func vendorConfirmPayment(conversationID: UUID) async throws -> BookingTransitionResult
    func cancelBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult
    func respondToCancellationRequest(conversationID: UUID, approved: Bool, reason: String?) async throws -> BookingTransitionResult
    func forceCancelBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult

    func checkVendorDateConflicts(vendorID: UUID, eventDate: Date) async throws -> [DateConflict]
    func fetchEventConfirmedVendors(eventID: UUID, requestingVendorID: UUID) async throws -> [CoBookedVendorRecord]
    func createConversationServer(vendorID: UUID, eventID: UUID?) async throws -> ConversationRecord
    func fetchConversationSummaries(role: String) async throws -> [ConversationSummaryRecord]

    func linkConversationToEvent(conversationID: UUID, eventID: UUID) async throws

    func fetchVendorNote(conversationID: UUID) async throws -> String?
    func saveVendorNote(conversationID: UUID, content: String) async throws
}

extension BookingServiceProtocol {
    func submitBookingRequest(conversationID: UUID, eventDate: Date, note: String) async throws -> BookingTransitionResult {
        try await submitBookingRequest(conversationID: conversationID, eventDate: eventDate, note: note, requestedTimeStart: nil, requestedTimeEnd: nil, title: nil, budgetLabel: nil, guestCountLabel: nil, requestedServices: nil)
    }

    func submitBookingRequest(conversationID: UUID, eventDate: Date, note: String, requestedTimeStart: String?, requestedTimeEnd: String?) async throws -> BookingTransitionResult {
        try await submitBookingRequest(conversationID: conversationID, eventDate: eventDate, note: note, requestedTimeStart: requestedTimeStart, requestedTimeEnd: requestedTimeEnd, title: nil, budgetLabel: nil, guestCountLabel: nil, requestedServices: nil)
    }
}
