import Foundation

enum BookingStage: String, Codable {
    case active
    case requested
    case accepted
    case declined
    case paymentRequested = "payment_requested"
    case paid
    case cancellationRequested = "cancellation_requested"
    case cancelled
    case completed

    var title: String {
        switch self {
        case .active: "Active"
        case .requested: "Requested"
        case .accepted: "Confirmed"
        case .declined: "Declined"
        case .paymentRequested: "Payment requested"
        case .paid: "Payment confirmed"
        case .cancellationRequested: "Cancellation requested"
        case .cancelled: "Cancelled"
        case .completed: "Completed"
        }
    }

    var vendorActionLabel: String {
        switch self {
        case .active: "Reply in chat"
        case .requested: "Review request"
        case .accepted: "Request payment"
        case .declined: "Declined"
        case .paymentRequested: "Awaiting payment"
        case .paid: "Payment confirmed"
        case .cancellationRequested: "Review cancellation"
        case .cancelled: "Cancelled"
        case .completed: "Completed"
        }
    }

    var tone: AccentTone {
        switch self {
        case .active: .sand
        case .requested: .gold
        case .accepted: .sage
        case .declined, .cancelled: .coral
        case .paymentRequested: .blue
        case .paid: .sage
        case .cancellationRequested: .gold
        case .completed: .blue
        }
    }

    var isConfirmed: Bool {
        switch self {
        case .paid, .completed: true
        case .active, .requested, .accepted, .declined, .paymentRequested, .cancellationRequested, .cancelled: false
        }
    }

    var requiresVendorAction: Bool {
        switch self {
        case .requested, .accepted, .cancellationRequested: true
        case .active, .declined, .paymentRequested, .paid, .cancelled, .completed: false
        }
    }

    var isTerminal: Bool {
        switch self {
        case .declined, .cancelled: true
        case .active, .requested, .accepted, .paymentRequested, .paid, .cancellationRequested, .completed: false
        }
    }

    var isRebookable: Bool {
        switch self {
        case .declined, .cancelled: true
        case .active, .requested, .accepted, .paymentRequested, .paid, .cancellationRequested, .completed: false
        }
    }

    var isCancellable: Bool {
        switch self {
        case .requested, .accepted, .paymentRequested, .paid: true
        case .active, .declined, .cancelled, .completed, .cancellationRequested: false
        }
    }

    var isActionable: Bool {
        switch self {
        case .requested, .accepted, .paymentRequested, .paid, .cancellationRequested: true
        case .active, .declined, .cancelled, .completed: false
        }
    }

    var requiresHostAction: Bool {
        switch self {
        case .paymentRequested, .cancellationRequested: true
        case .active, .requested, .accepted, .declined, .paid, .cancelled, .completed: false
        }
    }

    static func fromDatabaseValue(_ value: String) -> BookingStage {
        // Map old values to new ones for backward compatibility
        switch value {
        case "draft": .active
        case "vendor_reviewing": .requested
        case "quoted", "host_reviewing": .accepted
        case "deposit_pending": .paymentRequested
        case "confirmed": .paid
        default: BookingStage(rawValue: value) ?? .active
        }
    }
}
