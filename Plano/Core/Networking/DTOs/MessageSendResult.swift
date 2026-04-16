import Foundation

nonisolated struct MessageAttachmentUpload: Codable, Hashable, Sendable {
    let storagePath: String
    let fileName: String
    let mimeType: String
    let fileSizeBytes: Int64
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case storagePath = "storage_path"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case fileSizeBytes = "file_size_bytes"
        case width
        case height
    }
}

nonisolated struct MessageSendResult: Decodable, Hashable, Sendable {
    let message: MessageRecord
    let attachments: [MessageAttachmentRecord]

    init(
        message: MessageRecord,
        attachments: [MessageAttachmentRecord] = []
    ) {
        self.message = message
        self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(MessageRecord.self, forKey: .message)

        if let attachments = try container.decodeIfPresent([MessageAttachmentRecord].self, forKey: .attachments) {
            self.attachments = attachments
        } else if let attachment = try container.decodeIfPresent(MessageAttachmentRecord.self, forKey: .attachment) {
            self.attachments = [attachment]
        } else {
            self.attachments = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case message
        case attachments
        case attachment
    }
}
