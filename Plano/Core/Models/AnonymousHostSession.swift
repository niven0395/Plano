import Foundation

struct AnonymousHostSession: Hashable {
    let userID: UUID
    let displayName: String?
    let contactPhone: String?
    let contactEmail: String?
    let isLinkedToApple: Bool
    let emailAddress: String?

    var identityState: SessionIdentityState {
        if let displayName,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .identified(name: displayName.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return .anonymous
    }

    var resolvedDisplayName: String {
        if let displayName,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "Guest host"
    }
}

enum RestoredAuthSession: Hashable {
    case anonymous(AnonymousHostSession)
    case authenticated(AuthenticatedUserProfile)
}
