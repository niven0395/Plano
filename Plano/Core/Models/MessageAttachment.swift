import Foundation

struct MessageAttachment: Identifiable, Hashable, Sendable {
    let id: UUID
    let storagePath: String
    let fileName: String
    let mimeType: String
    let fileSizeBytes: Int64
    let width: Int?
    let height: Int?
    let thumbnailPath: String?
    var localURL: URL?
    var signedURL: URL?

    init(
        id: UUID = UUID(),
        storagePath: String,
        fileName: String,
        mimeType: String,
        fileSizeBytes: Int64,
        width: Int? = nil,
        height: Int? = nil,
        thumbnailPath: String? = nil,
        localURL: URL? = nil,
        signedURL: URL? = nil
    ) {
        self.id = id
        self.storagePath = storagePath
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileSizeBytes = fileSizeBytes
        self.width = width
        self.height = height
        self.thumbnailPath = thumbnailPath
        self.localURL = localURL
        self.signedURL = signedURL
    }

    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }

    var isPDF: Bool {
        mimeType == "application/pdf"
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    static let allowedMIMETypes: Set<String> = [
        "image/jpeg", "image/png", "image/heic", "image/heif", "image/webp",
        "application/pdf",
    ]

    static let maxFileSizeBytes: Int64 = 10_485_760 // 10 MB
    static let maxAttachmentsPerMessage = 5
}
