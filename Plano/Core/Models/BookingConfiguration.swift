import Foundation

// Legacy compatibility for older vendor profile records.
nonisolated enum AvailabilityMode: String, CaseIterable, Identifiable, Codable {
    case showCalendar = "show_calendar"
    case manualReview = "manual_review"
    case contactToDiscuss = "contact_to_discuss"

    var id: Self { self }

    var title: String {
        switch self {
        case .showCalendar:
            "Show calendar"
        case .manualReview:
            "Manual review"
        case .contactToDiscuss:
            "Contact to discuss"
        }
    }
}

nonisolated enum BookingMode: String, CaseIterable, Identifiable, Codable {
    case acceptOnline = "accept_online"
    case requestOnly = "request_only"
    case inquiryOnly = "inquiry_only"

    var id: Self { self }

    var title: String {
        switch self {
        case .acceptOnline:
            "Book online"
        case .requestOnly:
            "Request booking"
        case .inquiryOnly:
            "Send inquiry"
        }
    }

    var hostSummaryTitle: String {
        switch self {
        case .acceptOnline:
            "Instant book"
        case .requestOnly:
            "Approval required"
        case .inquiryOnly:
            "Inquiry first"
        }
    }

    var symbolName: String {
        switch self {
        case .acceptOnline:
            "bolt.fill"
        case .requestOnly:
            "checkmark.seal.fill"
        case .inquiryOnly:
            "bubble.left.and.text.bubble.right.fill"
        }
    }
}

nonisolated enum PaymentMode: String, CaseIterable, Identifiable, Codable {
    case platform
    case cashOnly = "cash_only"
    case external

    var id: Self { self }

    var title: String {
        switch self {
        case .platform:
            "In-app payments"
        case .cashOnly:
            "Cash only"
        case .external:
            "External payment"
        }
    }

    var hostSummaryTitle: String {
        switch self {
        case .platform:
            "Pay on Plano"
        case .cashOnly:
            "Cash payment"
        case .external:
            "Pay vendor directly"
        }
    }

    var hostDescription: String {
        switch self {
        case .platform:
            "Deposits can stay on Plano when the booking moves forward."
        case .cashOnly:
            "Payment happens outside Plano and is settled in cash with the vendor."
        case .external:
            "Payment happens outside Plano and is coordinated directly with the vendor."
        }
    }

    var symbolName: String {
        switch self {
        case .platform:
            "creditcard.fill"
        case .cashOnly:
            "banknote.fill"
        case .external:
            "arrow.left.arrow.right.circle.fill"
        }
    }

    var depositActionTitle: String {
        switch self {
        case .platform:
            "Pay deposit on Plano"
        case .cashOnly:
            "Record cash deposit"
        case .external:
            "Record direct deposit"
        }
    }

    var depositMethodLabel: String {
        switch self {
        case .platform:
            "Apple Pay"
        case .cashOnly:
            "Cash"
        case .external:
            "Direct payment"
        }
    }
}
