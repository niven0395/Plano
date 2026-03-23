import Foundation

nonisolated struct PlannedVendorRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let eventID: UUID
    let vendorID: UUID
    let category: String
    let status: String
    let availabilityCheckedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case vendorID = "vendor_id"
        case category
        case status
        case availabilityCheckedAt = "availability_checked_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        eventID: UUID,
        vendorID: UUID,
        category: String,
        status: String = "planned",
        availabilityCheckedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.eventID = eventID
        self.vendorID = vendorID
        self.category = category
        self.status = status
        self.availabilityCheckedAt = availabilityCheckedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var vendorCategory: VendorCategory {
        VendorCategory(rawValue: category) ?? .entertainer
    }

    var plannedVendorStatus: PlannedVendorStatus {
        PlannedVendorStatus(rawValue: status) ?? .planned
    }
}

enum PlannedVendorStatus: String, Codable, Hashable {
    case planned
    case requestSent = "request_sent"
    case booked
    case removed
}
