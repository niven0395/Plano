import Foundation

struct AuthenticatedUserProfile: Hashable {
    let userID: UUID
    let emailAddress: String?
    let displayName: String?
    let vendorDisplayName: String?

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

        if let emailAddress,
           let localPart = emailAddress.split(separator: "@").first,
           !localPart.isEmpty {
            return localPart.replacingOccurrences(of: ".", with: " ").capitalized
        }

        return "Plano User"
    }
}
