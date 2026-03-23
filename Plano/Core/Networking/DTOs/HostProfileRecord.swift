import Foundation

struct HostProfileRecord: Codable, Hashable {
    let userID: UUID
    let displayName: String
    let preferredCity: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case preferredCity = "preferred_city"
    }
}
