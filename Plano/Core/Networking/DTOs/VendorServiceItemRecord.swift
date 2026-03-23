import Foundation

nonisolated struct VendorServiceItemRecord: Codable, Hashable {
    let id: UUID
    let vendorID: UUID
    let title: String
    let priceCents: Int
    let description: String?
    let displayOrder: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case vendorID = "vendor_id"
        case title
        case priceCents = "price_cents"
        case description
        case displayOrder = "display_order"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        vendorID: UUID,
        title: String,
        priceCents: Int,
        description: String? = nil,
        displayOrder: Int,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.vendorID = vendorID
        self.title = title
        self.priceCents = priceCents
        self.description = description
        self.displayOrder = displayOrder
        self.createdAt = createdAt
    }

    init(item: VendorServiceItem, vendorID: UUID) {
        id = item.id
        self.vendorID = vendorID
        title = item.title
        priceCents = item.priceCents
        description = item.description.isEmpty ? nil : item.description
        displayOrder = item.displayOrder
        createdAt = nil
    }

    func makeServiceItem() -> VendorServiceItem {
        VendorServiceItem(
            id: id,
            title: title,
            priceCents: priceCents,
            description: description ?? "",
            displayOrder: displayOrder
        )
    }
}
