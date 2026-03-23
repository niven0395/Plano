import Foundation

enum PaymentType: String, CaseIterable, Identifiable, Hashable {
    case deposit
    case fullPayment = "full_payment"

    var id: Self { self }

    var title: String {
        switch self {
        case .deposit: "Deposit"
        case .fullPayment: "Full payment"
        }
    }

    var messagePrefix: String {
        switch self {
        case .deposit: "Deposit"
        case .fullPayment: "Full payment"
        }
    }
}

struct SimpleBookingRequest: Hashable {
    let eventDate: Date?
    let note: String
    let requestedTimeStart: String?
    let requestedTimeEnd: String?
    let submittedAt: Date?

    init(eventDate: Date? = nil, note: String = "", requestedTimeStart: String? = nil, requestedTimeEnd: String? = nil, submittedAt: Date? = nil) {
        self.eventDate = eventDate
        self.note = note
        self.requestedTimeStart = requestedTimeStart
        self.requestedTimeEnd = requestedTimeEnd
        self.submittedAt = submittedAt
    }
}

enum PaymentRequestStatus: Hashable {
    case pending
    case paid

    var title: String {
        switch self {
        case .pending: "Pending"
        case .paid: "Confirmed"
        }
    }

    var tone: AccentTone {
        switch self {
        case .pending: .blue
        case .paid: .sage
        }
    }
}

struct PaymentRequest: Identifiable, Hashable, Sendable {
    let id: UUID
    let amountCents: Int
    let amountLabel: String
    let note: String
    let requestedAt: Date?
    var status: PaymentRequestStatus
    let paymentType: PaymentType
    let vendorEmail: String?

    init(
        id: UUID = UUID(),
        amountCents: Int,
        amountLabel: String = "",
        note: String = "",
        requestedAt: Date? = nil,
        status: PaymentRequestStatus = .pending,
        paymentType: PaymentType = .deposit,
        vendorEmail: String? = nil
    ) {
        self.id = id
        self.amountCents = amountCents
        self.amountLabel = amountLabel.isEmpty
            ? CurrencyValueFormatter.label(forCents: amountCents, currencyCode: "CAD")
            : amountLabel
        self.note = note
        self.requestedAt = requestedAt
        self.status = status
        self.paymentType = paymentType
        self.vendorEmail = vendorEmail
    }
}

struct BookingRequestSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let conversationID: UUID?
    let vendorID: UUID?
    let eventID: UUID?
    let counterpartName: String
    let eventTitle: String
    let eventDateLabel: String
    let eventTimeLabel: String?
    let detail: String
    let amountLabel: String
    let stage: BookingStage

    init(
        id: UUID = UUID(),
        conversationID: UUID? = nil,
        vendorID: UUID? = nil,
        eventID: UUID? = nil,
        counterpartName: String,
        eventTitle: String,
        eventDateLabel: String,
        eventTimeLabel: String? = nil,
        detail: String,
        amountLabel: String,
        stage: BookingStage
    ) {
        self.id = id
        self.conversationID = conversationID
        self.vendorID = vendorID
        self.eventID = eventID
        self.counterpartName = counterpartName
        self.eventTitle = eventTitle
        self.eventDateLabel = eventDateLabel
        self.eventTimeLabel = eventTimeLabel
        self.detail = detail
        self.amountLabel = amountLabel
        self.stage = stage
    }

    func updating(stage: BookingStage, detail: String? = nil, amountLabel: String? = nil) -> BookingRequestSummary {
        BookingRequestSummary(
            id: id,
            conversationID: conversationID,
            vendorID: vendorID,
            eventID: eventID,
            counterpartName: counterpartName,
            eventTitle: eventTitle,
            eventDateLabel: eventDateLabel,
            eventTimeLabel: eventTimeLabel,
            detail: detail ?? self.detail,
            amountLabel: amountLabel ?? self.amountLabel,
            stage: stage
        )
    }
}
