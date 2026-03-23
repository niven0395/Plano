import Foundation

nonisolated struct DeletionResult: Codable, Sendable {
    let cancelledBookings: Int

    enum CodingKeys: String, CodingKey {
        case cancelledBookings = "cancelled_bookings"
    }
}
