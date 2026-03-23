import Foundation

enum EventStage: String, Codable, Hashable {
    case planning
    case requesting
    case confirming
    case ready
    case completed
    case cancelled

    var title: String {
        switch self {
        case .planning:
            "Planning"
        case .requesting:
            "Requesting vendors"
        case .confirming:
            "Confirming vendors"
        case .ready:
            "Ready"
        case .completed:
            "Completed"
        case .cancelled:
            "Cancelled"
        }
    }

    var tone: AccentTone {
        switch self {
        case .planning:
            .sand
        case .requesting:
            .gold
        case .confirming:
            .blue
        case .ready:
            .sage
        case .completed:
            .blue
        case .cancelled:
            .coral
        }
    }

    /// Derive event stage from the aggregate state of its bookings.
    static func derived(from bookingStages: [BookingStage]) -> EventStage {
        guard !bookingStages.isEmpty else { return .planning }

        let active = bookingStages.filter { $0 != .declined && $0 != .cancelled }
        guard !active.isEmpty else { return .planning }

        let allConfirmedOrCompleted = active.allSatisfy { $0.isConfirmed }
        if allConfirmedOrCompleted { return .ready }

        let hasConfirmed = active.contains { $0.isConfirmed }
        let hasPending = active.contains { $0 != .paid && $0 != .completed }

        if hasConfirmed && hasPending { return .confirming }

        let hasRequested = active.contains {
            $0 == .requested || $0 == .accepted
        }
        if hasRequested { return .requesting }

        return .planning
    }
}
