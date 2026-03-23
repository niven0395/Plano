import Foundation

nonisolated struct UserRecord: Codable, Hashable {
    let id: UUID
    let email: String?
    let displayName: String
    let preferredRole: String
    let anonymousDisplayName: String?
    let contactPhone: String?
    let contactEmail: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case preferredRole = "preferred_role"
        case anonymousDisplayName = "anonymous_display_name"
        case contactPhone = "contact_phone"
        case contactEmail = "contact_email"
    }
}
