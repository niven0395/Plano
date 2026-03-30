import Foundation

nonisolated struct VendorPackageRecord: Codable, Hashable {
    let id: UUID
    let vendorID: UUID
    let title: String
    let priceCents: Int
    let description: String?
    let includedItems: [String]
    let isHighlighted: Bool
    let pricingUnit: String?
    let displayOrder: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case vendorID = "vendor_id"
        case title
        case priceCents = "price_cents"
        case description
        case includedItems = "included_items"
        case isHighlighted = "is_highlighted"
        case pricingUnit = "pricing_unit"
        case displayOrder = "display_order"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        vendorID: UUID,
        title: String,
        priceCents: Int,
        description: String? = nil,
        includedItems: [String] = [],
        isHighlighted: Bool = false,
        pricingUnit: String? = nil,
        displayOrder: Int,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.vendorID = vendorID
        self.title = title
        self.priceCents = priceCents
        self.description = description
        self.includedItems = includedItems
        self.isHighlighted = isHighlighted
        self.pricingUnit = pricingUnit
        self.displayOrder = displayOrder
        self.createdAt = createdAt
    }

    init(package: VendorPackage, vendorID: UUID) {
        id = package.id
        self.vendorID = vendorID
        title = package.title
        priceCents = package.priceCents
        description = package.description.isEmpty ? nil : package.description
        includedItems = package.includedItems
        isHighlighted = package.isHighlighted
        pricingUnit = package.pricingUnit
        displayOrder = package.displayOrder
        createdAt = nil
    }

    func makePackage() -> VendorPackage {
        VendorPackage(
            id: id,
            title: title,
            priceCents: priceCents,
            description: description ?? "",
            includedItems: includedItems,
            isHighlighted: isHighlighted,
            pricingUnit: pricingUnit,
            displayOrder: displayOrder
        )
    }
}
