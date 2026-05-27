import Foundation

nonisolated struct BookingRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let conversationID: UUID
    let eventID: UUID?
    let vendorID: UUID
    let hostID: UUID?
    let depositAmountLabel: String?
    let depositAmountCents: Int?
    let totalAmountCents: Int?
    let currency: String?
    let eventDate: Date?
    let stripePaymentIntentID: String?
    let depositMethod: String?
    let depositPaidAt: Date?
    let paymentRequestedAmountCents: Int?
    let paymentRequestedAt: Date?
    let paymentRequestNote: String?
    let paymentConfirmedAt: Date?
    let paymentType: String?
    let paymentReminderSentAt: Date?
    let cancelledBy: UUID?
    let cancelledAt: Date?
    let cancellationReason: String?
    let cancellationRequestedBy: UUID?
    let cancellationRequestedAt: Date?
    let cancellationRequestReason: String?
    let stageBeforeCancellationRequest: String?
    let cancellationRequestDeadline: Date?
    let cancellationResponseBy: UUID?
    let cancellationDeclinedAt: Date?
    let forceCancelled: Bool?
    let stage: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case eventID = "event_id"
        case vendorID = "vendor_id"
        case hostID = "host_id"
        case depositAmountLabel = "deposit_amount_label"
        case depositAmountCents = "deposit_amount_cents"
        case totalAmountCents = "total_amount_cents"
        case currency
        case eventDate = "event_date"
        case stripePaymentIntentID = "stripe_payment_intent_id"
        case depositMethod = "deposit_method"
        case depositPaidAt = "deposit_paid_at"
        case paymentRequestedAmountCents = "payment_requested_amount_cents"
        case paymentRequestedAt = "payment_requested_at"
        case paymentRequestNote = "payment_request_note"
        case paymentConfirmedAt = "payment_confirmed_at"
        case paymentType = "payment_type"
        case paymentReminderSentAt = "payment_reminder_sent_at"
        case cancelledBy = "cancelled_by"
        case cancelledAt = "cancelled_at"
        case cancellationReason = "cancellation_reason"
        case cancellationRequestedBy = "cancellation_requested_by"
        case cancellationRequestedAt = "cancellation_requested_at"
        case cancellationRequestReason = "cancellation_request_reason"
        case stageBeforeCancellationRequest = "stage_before_cancellation_request"
        case cancellationRequestDeadline = "cancellation_request_deadline"
        case cancellationResponseBy = "cancellation_response_by"
        case cancellationDeclinedAt = "cancellation_declined_at"
        case forceCancelled = "force_cancelled"
        case stage
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        conversationID: UUID,
        eventID: UUID?,
        vendorID: UUID,
        hostID: UUID?,
        depositAmountLabel: String? = nil,
        depositAmountCents: Int? = nil,
        totalAmountCents: Int? = nil,
        currency: String? = nil,
        eventDate: Date? = nil,
        stripePaymentIntentID: String? = nil,
        depositMethod: String? = nil,
        depositPaidAt: Date? = nil,
        paymentRequestedAmountCents: Int? = nil,
        paymentRequestedAt: Date? = nil,
        paymentRequestNote: String? = nil,
        paymentConfirmedAt: Date? = nil,
        paymentType: String? = nil,
        paymentReminderSentAt: Date? = nil,
        cancelledBy: UUID? = nil,
        cancelledAt: Date? = nil,
        cancellationReason: String? = nil,
        cancellationRequestedBy: UUID? = nil,
        cancellationRequestedAt: Date? = nil,
        cancellationRequestReason: String? = nil,
        stageBeforeCancellationRequest: String? = nil,
        cancellationRequestDeadline: Date? = nil,
        cancellationResponseBy: UUID? = nil,
        cancellationDeclinedAt: Date? = nil,
        forceCancelled: Bool? = nil,
        stage: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.eventID = eventID
        self.vendorID = vendorID
        self.hostID = hostID
        self.depositAmountLabel = depositAmountLabel
        self.depositAmountCents = depositAmountCents
        self.totalAmountCents = totalAmountCents
        self.currency = currency
        self.eventDate = eventDate
        self.stripePaymentIntentID = stripePaymentIntentID
        self.depositMethod = depositMethod
        self.depositPaidAt = depositPaidAt
        self.paymentRequestedAmountCents = paymentRequestedAmountCents
        self.paymentRequestedAt = paymentRequestedAt
        self.paymentRequestNote = paymentRequestNote
        self.paymentConfirmedAt = paymentConfirmedAt
        self.paymentType = paymentType
        self.paymentReminderSentAt = paymentReminderSentAt
        self.cancelledBy = cancelledBy
        self.cancelledAt = cancelledAt
        self.cancellationReason = cancellationReason
        self.cancellationRequestedBy = cancellationRequestedBy
        self.cancellationRequestedAt = cancellationRequestedAt
        self.cancellationRequestReason = cancellationRequestReason
        self.stageBeforeCancellationRequest = stageBeforeCancellationRequest
        self.cancellationRequestDeadline = cancellationRequestDeadline
        self.cancellationResponseBy = cancellationResponseBy
        self.cancellationDeclinedAt = cancellationDeclinedAt
        self.forceCancelled = forceCancelled
        self.stage = stage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        conversationID = try container.decode(UUID.self, forKey: .conversationID)
        eventID = try container.decodeIfPresent(UUID.self, forKey: .eventID)
        vendorID = try container.decode(UUID.self, forKey: .vendorID)
        hostID = try container.decodeIfPresent(UUID.self, forKey: .hostID)
        depositAmountLabel = try container.decodeIfPresent(String.self, forKey: .depositAmountLabel)
        depositAmountCents = try container.decodeIfPresent(Int.self, forKey: .depositAmountCents)
        totalAmountCents = try container.decodeIfPresent(Int.self, forKey: .totalAmountCents)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        eventDate = try PostgresDateValueDecoder.decodeIfPresent(forKey: .eventDate, from: container)
        stripePaymentIntentID = try container.decodeIfPresent(String.self, forKey: .stripePaymentIntentID)
        depositMethod = try container.decodeIfPresent(String.self, forKey: .depositMethod)
        depositPaidAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .depositPaidAt, from: container)
        paymentRequestedAmountCents = try container.decodeIfPresent(Int.self, forKey: .paymentRequestedAmountCents)
        paymentRequestedAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .paymentRequestedAt, from: container)
        paymentRequestNote = try container.decodeIfPresent(String.self, forKey: .paymentRequestNote)
        paymentConfirmedAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .paymentConfirmedAt, from: container)
        paymentType = try container.decodeIfPresent(String.self, forKey: .paymentType)
        paymentReminderSentAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .paymentReminderSentAt, from: container)
        cancelledBy = try container.decodeIfPresent(UUID.self, forKey: .cancelledBy)
        cancelledAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .cancelledAt, from: container)
        cancellationReason = try container.decodeIfPresent(String.self, forKey: .cancellationReason)
        cancellationRequestedBy = try container.decodeIfPresent(UUID.self, forKey: .cancellationRequestedBy)
        cancellationRequestedAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .cancellationRequestedAt, from: container)
        cancellationRequestReason = try container.decodeIfPresent(String.self, forKey: .cancellationRequestReason)
        stageBeforeCancellationRequest = try container.decodeIfPresent(String.self, forKey: .stageBeforeCancellationRequest)
        cancellationRequestDeadline = try PostgresDateValueDecoder.decodeIfPresent(forKey: .cancellationRequestDeadline, from: container)
        cancellationResponseBy = try container.decodeIfPresent(UUID.self, forKey: .cancellationResponseBy)
        cancellationDeclinedAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .cancellationDeclinedAt, from: container)
        forceCancelled = try container.decodeIfPresent(Bool.self, forKey: .forceCancelled)
        stage = try container.decode(String.self, forKey: .stage)
        createdAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .createdAt, from: container)
        updatedAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .updatedAt, from: container)
    }
}
