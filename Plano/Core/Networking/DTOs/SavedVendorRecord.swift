import Foundation

nonisolated struct SavedVendorRecord: Codable, Hashable, Sendable {
    let hostID: UUID
    let vendorID: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case hostID = "host_id"
        case vendorID = "vendor_id"
        case createdAt = "created_at"
    }

    init(
        hostID: UUID,
        vendorID: UUID,
        createdAt: Date? = nil
    ) {
        self.hostID = hostID
        self.vendorID = vendorID
        self.createdAt = createdAt
    }
}
