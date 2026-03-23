import Foundation

enum MessageDeliveryStatus: String, Codable, Hashable, Sendable {
    case sending
    case sent
    case delivered
    case read
    case failed
}
