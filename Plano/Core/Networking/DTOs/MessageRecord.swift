import Foundation

nonisolated struct MessageRecord: Codable, Hashable {
    let id: UUID
    let conversationID: UUID
    let senderRole: String
    let body: String
    let kind: String
    let createdAt: Date
    let status: String?
    let clientID: UUID?
    let sequenceNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case senderRole = "sender_role"
        case body
        case kind
        case createdAt = "created_at"
        case status
        case clientID = "client_id"
        case sequenceNumber = "sequence_number"
    }

    init(
        id: UUID,
        conversationID: UUID,
        senderRole: String,
        body: String,
        kind: String,
        createdAt: Date,
        status: String? = nil,
        clientID: UUID? = nil,
        sequenceNumber: Int? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderRole = senderRole
        self.body = body
        self.kind = kind
        self.createdAt = createdAt
        self.status = status
        self.clientID = clientID
        self.sequenceNumber = sequenceNumber
    }
}
