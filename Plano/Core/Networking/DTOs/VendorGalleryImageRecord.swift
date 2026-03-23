import Foundation

nonisolated struct VendorGalleryImageRecord: Codable, Hashable {
    let id: UUID
    let vendorID: UUID
    let storagePath: String
    let displayOrder: Int
    let caption: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case vendorID = "vendor_id"
        case storagePath = "storage_path"
        case displayOrder = "display_order"
        case caption
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        vendorID: UUID,
        storagePath: String,
        displayOrder: Int,
        caption: String?,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.vendorID = vendorID
        self.storagePath = storagePath
        self.displayOrder = displayOrder
        self.caption = caption
        self.createdAt = createdAt
    }

    init(image: VendorGalleryImage, vendorID: UUID) {
        id = image.id
        self.vendorID = vendorID
        storagePath = image.storagePath
        displayOrder = image.displayOrder
        caption = image.caption
        createdAt = nil
    }

    func makeImage() -> VendorGalleryImage {
        VendorGalleryImage(
            id: id,
            storagePath: storagePath,
            displayOrder: displayOrder,
            caption: caption ?? ""
        )
    }
}
