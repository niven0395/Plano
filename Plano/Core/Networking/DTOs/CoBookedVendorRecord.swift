import Foundation

struct CoBookedVendorRecord: Codable, Hashable {
    let vendorID: UUID
    let vendorDisplayName: String
    let vendorCategory: String

    enum CodingKeys: String, CodingKey {
        case vendorID = "vendor_id"
        case vendorDisplayName = "vendor_display_name"
        case vendorCategory = "vendor_category"
    }

    func toDomain() -> CoBookedVendor {
        CoBookedVendor(
            vendorID: vendorID,
            displayName: vendorDisplayName,
            category: VendorCategory.fromDatabaseValue(vendorCategory) ?? .entertainer
        )
    }
}
