import Foundation

protocol MessagingServiceProtocol: Sendable {
    /// Fetch messages with cursor-based pagination.
    /// - Parameters:
    ///   - conversationID: The conversation to fetch messages from.
    ///   - cursor: Fetch messages created before this date. Pass nil for the latest page.
    ///   - limit: Maximum number of messages to return.
    func fetchMessages(
        conversationID: UUID,
        before cursor: Date?,
        limit: Int
    ) async throws -> [MessageRecord]

    /// Send a message with a client-generated ID for deduplication.
    func sendMessage(
        conversationID: UUID,
        body: String,
        kind: String,
        senderRole: String,
        clientID: UUID
    ) async throws -> MessageRecord

    /// Send a message with an attachment via edge function (upload must be done first).
    func sendMessageWithAttachment(
        conversationID: UUID,
        body: String,
        kind: String,
        clientID: UUID,
        storagePath: String,
        fileName: String,
        mimeType: String,
        fileSizeBytes: Int64,
        width: Int?,
        height: Int?
    ) async throws -> MessageRecord

    /// Mark all messages in a conversation as read for the given role.
    func markMessagesRead(
        conversationID: UUID,
        role: String
    ) async throws

    /// Upload an attachment to storage and return the storage path.
    func uploadAttachment(
        data: Data,
        fileName: String,
        mimeType: String,
        userID: UUID
    ) async throws -> String

    /// Create attachment record linked to a message.
    func createAttachmentRecord(
        messageID: UUID,
        storagePath: String,
        fileName: String,
        mimeType: String,
        fileSizeBytes: Int64,
        width: Int?,
        height: Int?
    ) async throws -> MessageAttachmentRecord

    /// Fetch attachment records for a set of message IDs.
    func fetchAttachments(messageIDs: [UUID]) async throws -> [MessageAttachmentRecord]

    /// Generate a signed URL for an attachment.
    func signedURL(for storagePath: String) async throws -> URL

    /// Mark a message as delivered (recipient has received it).
    func markMessageDelivered(messageID: UUID) async throws

    /// Fetch messages created after a given date (for catch-up sync after reconnection).
    func fetchMessagesSince(
        conversationID: UUID,
        after: Date,
        limit: Int
    ) async throws -> [MessageRecord]

    /// Fetch messages with sequence number greater than the given value.
    func fetchMessagesSinceSequence(
        conversationID: UUID,
        afterSequence: Int,
        limit: Int
    ) async throws -> [MessageRecord]

    /// Register a device token for push notifications.
    func registerDeviceToken(_ token: String, userID: UUID) async throws

    /// Remove a device token.
    func removeDeviceToken(_ token: String, userID: UUID) async throws
}
