import Foundation

struct CoBookedVendor: Identifiable, Hashable {
    let vendorID: UUID
    let displayName: String
    let category: VendorCategory

    var id: UUID { vendorID }
}
