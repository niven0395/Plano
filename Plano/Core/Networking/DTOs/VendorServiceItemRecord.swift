import Foundation

nonisolated struct VendorServiceItemRecord: Codable, Hashable {
    let id: UUID
    let vendorID: UUID
    let title: String
    let priceCents: Int
    let description: String?
    let displayOrder: Int
    let itemType: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case vendorID = "vendor_id"
        case title
        case priceCents = "price_cents"
        case description
        case displayOrder = "display_order"
        case itemType = "item_type"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        vendorID: UUID,
        title: String,
        priceCents: Int,
        description: String? = nil,
        displayOrder: Int,
        itemType: String = "service",
        createdAt: Date? = nil
    ) {
        self.id = id
        self.vendorID = vendorID
        self.title = title
        self.priceCents = priceCents
        self.description = description
        self.displayOrder = displayOrder
        self.itemType = itemType
        self.createdAt = createdAt
    }

    init(item: VendorServiceItem, vendorID: UUID) {
        id = item.id
        self.vendorID = vendorID
        title = item.title
        priceCents = item.priceCents
        description = item.description.isEmpty ? nil : item.description
        displayOrder = item.displayOrder
        itemType = "service"
        createdAt = nil
    }

    init(addOn: VendorAddOn, vendorID: UUID) {
        id = addOn.id
        self.vendorID = vendorID
        title = addOn.title
        priceCents = addOn.priceCents
        description = addOn.description.isEmpty ? nil : addOn.description
        displayOrder = addOn.displayOrder
        itemType = "addon"
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

    func makeAddOn() -> VendorAddOn {
        VendorAddOn(
            id: id,
            title: title,
            priceCents: priceCents,
            description: description ?? "",
            displayOrder: displayOrder
        )
    }
}
