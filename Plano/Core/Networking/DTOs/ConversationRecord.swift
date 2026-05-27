import Foundation

nonisolated struct ConversationRecord: Codable, Hashable {
    let id: UUID
    let eventID: UUID?
    let vendorID: UUID
    let hostID: UUID?
    let hostDisplayName: String
    let vendorDisplayName: String
    let vendorCategory: String
    let eventTitle: String?
    let eventDateLabel: String?
    let eventContextLine: String?
    let stage: String
    let lastActivityAt: Date
    let createdAt: Date?
    let updatedAt: Date?
    let hostUnreadCount: Int?
    let vendorUnreadCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case vendorID = "vendor_id"
        case hostID = "host_id"
        case hostDisplayName = "host_display_name"
        case vendorDisplayName = "vendor_display_name"
        case vendorCategory = "vendor_category"
        case eventTitle = "event_title"
        case eventDateLabel = "event_date_label"
        case eventContextLine = "event_context_line"
        case stage
        case lastActivityAt = "last_activity_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case hostUnreadCount = "host_unread_count"
        case vendorUnreadCount = "vendor_unread_count"
    }

    init(
        id: UUID,
        eventID: UUID?,
        vendorID: UUID,
        hostID: UUID?,
        hostDisplayName: String,
        vendorDisplayName: String,
        vendorCategory: String,
        eventTitle: String?,
        eventDateLabel: String?,
        eventContextLine: String?,
        stage: String,
        lastActivityAt: Date,
        createdAt: Date?,
        updatedAt: Date?,
        hostUnreadCount: Int?,
        vendorUnreadCount: Int?
    ) {
        self.id = id
        self.eventID = eventID
        self.vendorID = vendorID
        self.hostID = hostID
        self.hostDisplayName = hostDisplayName
        self.vendorDisplayName = vendorDisplayName
        self.vendorCategory = vendorCategory
        self.eventTitle = eventTitle
        self.eventDateLabel = eventDateLabel
        self.eventContextLine = eventContextLine
        self.stage = stage
        self.lastActivityAt = lastActivityAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.hostUnreadCount = hostUnreadCount
        self.vendorUnreadCount = vendorUnreadCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        eventID = try container.decodeIfPresent(UUID.self, forKey: .eventID)
        vendorID = try container.decode(UUID.self, forKey: .vendorID)
        hostID = try container.decodeIfPresent(UUID.self, forKey: .hostID)
        hostDisplayName = try container.decode(String.self, forKey: .hostDisplayName)
        vendorDisplayName = try container.decode(String.self, forKey: .vendorDisplayName)
        vendorCategory = try container.decode(String.self, forKey: .vendorCategory)
        eventTitle = try container.decodeIfPresent(String.self, forKey: .eventTitle)
        eventDateLabel = try container.decodeIfPresent(String.self, forKey: .eventDateLabel)
        eventContextLine = try container.decodeIfPresent(String.self, forKey: .eventContextLine)
        stage = try container.decode(String.self, forKey: .stage)
        lastActivityAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .lastActivityAt, from: container) ?? Date()
        createdAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .createdAt, from: container)
        updatedAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .updatedAt, from: container)
        hostUnreadCount = try container.decodeIfPresent(Int.self, forKey: .hostUnreadCount)
        vendorUnreadCount = try container.decodeIfPresent(Int.self, forKey: .vendorUnreadCount)
    }
}
