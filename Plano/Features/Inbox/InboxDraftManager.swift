import Foundation

@MainActor
final class InboxDraftManager {
    private static let draftsKey = "plano.inbox.drafts"
    private let defaults: UserDefaults

    private(set) var draftsByKey: [String: String]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        draftsByKey = defaults.dictionary(forKey: Self.draftsKey) as? [String: String] ?? [:]
    }

    func draft(for conversationID: UUID, role: UserRole) -> String {
        draftsByKey[draftKey(for: conversationID, role: role)] ?? ""
    }

    func updateDraft(_ text: String, for conversationID: UUID, role: UserRole) {
        let key = draftKey(for: conversationID, role: role)

        if text.isEmpty {
            draftsByKey.removeValue(forKey: key)
        } else {
            draftsByKey[key] = text
        }

        defaults.set(draftsByKey, forKey: Self.draftsKey)
    }

    /// Allows InboxStore to set the full dictionary (for observation bridging).
    func setDrafts(_ newValue: [String: String]) {
        draftsByKey = newValue
        defaults.set(draftsByKey, forKey: Self.draftsKey)
    }

    private func draftKey(for conversationID: UUID, role: UserRole) -> String {
        "\(role.rawValue).\(conversationID.uuidString)"
    }
}
