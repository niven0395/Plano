import Foundation

@MainActor
final class InboxArchiveManager {
    private static let archivedKey = "plano.inbox.archived"
    private let defaults: UserDefaults

    private(set) var archivedConversationKeys: Set<String>

    init(defaults: UserDefaults) {
        self.defaults = defaults
        archivedConversationKeys = Set(defaults.stringArray(forKey: Self.archivedKey) ?? [])
    }

    func archive(_ conversationID: UUID, for role: UserRole) {
        let key = archiveKey(for: conversationID, role: role)
        archivedConversationKeys.insert(key)
        persist()
    }

    func unarchive(_ conversationID: UUID, for role: UserRole) {
        let key = archiveKey(for: conversationID, role: role)
        archivedConversationKeys.remove(key)
        persist()
    }

    func isArchived(_ conversationID: UUID, for role: UserRole) -> Bool {
        archivedConversationKeys.contains(archiveKey(for: conversationID, role: role))
    }

    /// Allows InboxStore to set the full set (for observation bridging).
    func setArchivedKeys(_ newValue: Set<String>) {
        archivedConversationKeys = newValue
        persist()
    }

    private func archiveKey(for conversationID: UUID, role: UserRole) -> String {
        "\(role.rawValue).\(conversationID.uuidString)"
    }

    private func persist() {
        defaults.set(Array(archivedConversationKeys), forKey: Self.archivedKey)
    }
}
