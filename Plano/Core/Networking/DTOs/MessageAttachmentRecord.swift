import Foundation

nonisolated struct MessageAttachmentRecord: Codable, Hashable {
    let id: UUID
    let messageID: UUID
    let storagePath: String
    let fileName: String
    let mimeType: String
    let fileSizeBytes: Int64
    let width: Int?
    let height: Int?
    let thumbnailPath: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case messageID = "message_id"
        case storagePath = "storage_path"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case fileSizeBytes = "file_size_bytes"
        case width
        case height
        case thumbnailPath = "thumbnail_path"
        case createdAt = "created_at"
    }

    func toAttachment() -> MessageAttachment {
        MessageAttachment(
            id: id,
            storagePath: storagePath,
            fileName: fileName,
            mimeType: mimeType,
            fileSizeBytes: fileSizeBytes,
            width: width,
            height: height,
            thumbnailPath: thumbnailPath
        )
    }
}
