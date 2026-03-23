import Foundation
import SwiftData

@Model
final class CachedAttachment {
    #Index<CachedAttachment>([\.messageID])
    @Attribute(.unique) var attachmentID: UUID
    var messageID: UUID
    var storagePath: String
    var fileName: String
    var mimeType: String
    var fileSizeBytes: Int64
    var width: Int?
    var height: Int?
    var thumbnailPath: String?
    var createdAt: Date

    init(
        attachmentID: UUID,
        messageID: UUID,
        storagePath: String,
        fileName: String,
        mimeType: String,
        fileSizeBytes: Int64,
        width: Int? = nil,
        height: Int? = nil,
        thumbnailPath: String? = nil,
        createdAt: Date
    ) {
        self.attachmentID = attachmentID
        self.messageID = messageID
        self.storagePath = storagePath
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileSizeBytes = fileSizeBytes
        self.width = width
        self.height = height
        self.thumbnailPath = thumbnailPath
        self.createdAt = createdAt
    }
}

extension CachedAttachment {
    func toAttachment() -> MessageAttachment {
        MessageAttachment(
            id: attachmentID,
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
