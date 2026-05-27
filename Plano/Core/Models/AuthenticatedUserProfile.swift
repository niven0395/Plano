import Foundation

struct AuthenticatedUserProfile: Hashable {
    let userID: UUID
    let emailAddress: String?
    let displayName: String?
    let vendorDisplayName: String?
    let isEmailVerified: Bool

    init(
        userID: UUID,
        emailAddress: String?,
        displayName: String?,
        vendorDisplayName: String?,
        isEmailVerified: Bool = true
    ) {
        self.userID = userID
        self.emailAddress = emailAddress
        self.displayName = displayName
        self.vendorDisplayName = vendorDisplayName
        self.isEmailVerified = isEmailVerified
    }

    var isVendorOnboarded: Bool {
        vendorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func supports(_ role: UserRole) -> Bool {
        switch role {
        case .host:
            true
        case .vendor:
            isVendorOnboarded
        }
    }

    func displayName(for role: UserRole) -> String {
        switch role {
        case .vendor:
            vendorDisplayName ?? personalDisplayName
        case .host:
            personalDisplayName
        }
    }

    var personalDisplayName: String {
        if let displayName,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let derived = AuthenticatedUserProfile.displayName(fromEmail: emailAddress) {
            return derived
        }

        return "Plano User"
    }

    /// Best-effort name derived from an email's local-part. Returns `nil` if the
    /// local-part is one mashed word (no separators) — better to fall back to a
    /// neutral default than show something like "Nikhilsivarajah".
    nonisolated static func displayName(fromEmail email: String?) -> String? {
        guard let email,
              let localPart = email.split(separator: "@").first,
              !localPart.isEmpty
        else { return nil }

        let separators = CharacterSet(charactersIn: "._-+")
        let parts = localPart
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        guard parts.count >= 2 else { return nil }
        return parts.joined(separator: " ").capitalized
    }
}
