import Foundation

nonisolated struct DateConflict: Codable, Hashable, Identifiable, Sendable {
    let conversationID: UUID
    let eventTitle: String
    let hostDisplayName: String
    let stage: String

    var id: UUID { conversationID }

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case eventTitle = "event_title"
        case hostDisplayName = "host_display_name"
        case stage
    }
}

nonisolated struct BookingTransitionResult: Codable, Hashable, Sendable {
    let conversationID: UUID
    let stage: String
    let bookingID: UUID?
    let dateConflicts: [DateConflict]?
    let cancellationRequestDeadline: Date?
    let cancellationResponseBy: UUID?
    let cancellationRequestedBy: UUID?
    let cancellationDeclinedAt: Date?
    let forceCancelled: Bool?

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case stage
        case bookingID = "booking_id"
        case dateConflicts = "date_conflicts"
        case cancellationRequestDeadline = "cancellation_request_deadline"
        case cancellationResponseBy = "cancellation_response_by"
        case cancellationRequestedBy = "cancellation_requested_by"
        case cancellationDeclinedAt = "cancellation_declined_at"
        case forceCancelled = "force_cancelled"
    }

    init(
        conversationID: UUID,
        stage: String,
        bookingID: UUID?,
        dateConflicts: [DateConflict]?,
        cancellationRequestDeadline: Date? = nil,
        cancellationResponseBy: UUID? = nil,
        cancellationRequestedBy: UUID? = nil,
        cancellationDeclinedAt: Date? = nil,
        forceCancelled: Bool? = nil
    ) {
        self.conversationID = conversationID
        self.stage = stage
        self.bookingID = bookingID
        self.dateConflicts = dateConflicts
        self.cancellationRequestDeadline = cancellationRequestDeadline
        self.cancellationResponseBy = cancellationResponseBy
        self.cancellationRequestedBy = cancellationRequestedBy
        self.cancellationDeclinedAt = cancellationDeclinedAt
        self.forceCancelled = forceCancelled
    }
}

nonisolated struct DateConflictEnvelope: Codable, Hashable, Sendable {
    let conflicts: [DateConflict]
}

nonisolated struct SubmitBookingRequestV2Payload: Encodable, Sendable {
    let conversationID: UUID
    let eventDate: String
    let note: String
    let requestedTimeStart: String?
    let requestedTimeEnd: String?
    let idempotencyKey: UUID
    let title: String?
    let budgetLabel: String?
    let guestCountLabel: String?
    let requestedServices: [String]?
    let intakeAnswers: [LeadIntakeAnswer]?

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case eventDate = "event_date"
        case note
        case requestedTimeStart = "requested_time_start"
        case requestedTimeEnd = "requested_time_end"
        case idempotencyKey = "idempotency_key"
        case title
        case budgetLabel = "budget_label"
        case guestCountLabel = "guest_count_label"
        case requestedServices = "requested_services"
        case intakeAnswers = "intake_answers"
    }
}

nonisolated struct AcceptBookingPayload: Encodable, Sendable {
    let conversationID: UUID
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case idempotencyKey = "idempotency_key"
    }
}

nonisolated struct DeclineBookingPayload: Encodable, Sendable {
    let conversationID: UUID
    let reason: String?
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case reason
        case idempotencyKey = "idempotency_key"
    }
}

nonisolated struct RequestPaymentPayload: Encodable, Sendable {
    let conversationID: UUID
    let amountCents: Int
    let note: String?
    let paymentType: String?
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case amountCents = "amount_cents"
        case note
        case paymentType = "payment_type"
        case idempotencyKey = "idempotency_key"
    }
}

nonisolated struct ConfirmPaymentPayload: Encodable, Sendable {
    let conversationID: UUID
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case idempotencyKey = "idempotency_key"
    }
}

nonisolated struct VendorConfirmPaymentPayload: Encodable, Sendable {
    let conversationID: UUID
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case idempotencyKey = "idempotency_key"
    }
}

nonisolated struct CancelBookingPayload: Encodable, Sendable {
    let conversationID: UUID
    let reason: String?
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case reason
        case idempotencyKey = "idempotency_key"
    }
}

nonisolated struct RespondToCancellationPayload: Encodable, Sendable {
    let conversationID: UUID
    let approved: Bool
    let reason: String?
    let idempotencyKey: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case approved
        case reason
        case idempotencyKey = "idempotency_key"
    }
}

nonisolated struct CheckVendorDateConflictsPayload: Encodable, Sendable {
    let vendorID: UUID
    let eventDate: String

    enum CodingKeys: String, CodingKey {
        case vendorID = "vendor_id"
        case eventDate = "event_date"
    }
}
