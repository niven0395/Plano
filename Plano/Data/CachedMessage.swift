import Foundation
import SwiftData

@Model
final class CachedMessage {
    #Index<CachedMessage>([\.conversationID, \.createdAt])
    @Attribute(.unique) var messageID: UUID
    var conversationID: UUID
    var senderRole: String
    var body: String
    var kind: String
    var createdAt: Date
    var sequenceNumber: Int?
    var status: String
    var clientID: UUID?
    /// Tracks local sync state: "synced" for server-confirmed, "local" for outbox-pending.
    var syncState: String

    init(
        messageID: UUID,
        conversationID: UUID,
        senderRole: String,
        body: String,
        kind: String,
        createdAt: Date,
        sequenceNumber: Int? = nil,
        status: String,
        clientID: UUID? = nil,
        syncState: String = "synced"
    ) {
        self.messageID = messageID
        self.conversationID = conversationID
        self.senderRole = senderRole
        self.body = body
        self.kind = kind
        self.createdAt = createdAt
        self.sequenceNumber = sequenceNumber
        self.status = status
        self.clientID = clientID
        self.syncState = syncState
    }
}

extension CachedMessage {
    func toMessageRecord() -> MessageRecord {
        MessageRecord(
            id: messageID,
            conversationID: conversationID,
            senderRole: senderRole,
            body: body,
            kind: kind,
            createdAt: createdAt,
            status: status,
            clientID: clientID,
            sequenceNumber: sequenceNumber
        )
    }

    func update(from record: MessageRecord) {
        senderRole = record.senderRole
        body = record.body
        kind = record.kind
        createdAt = record.createdAt
        sequenceNumber = record.sequenceNumber
        status = record.status ?? "sent"
        clientID = record.clientID
        syncState = "synced"
    }
}
