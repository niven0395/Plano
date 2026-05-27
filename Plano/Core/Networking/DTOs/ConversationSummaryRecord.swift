import Foundation

nonisolated struct ConversationSummaryRecord: Codable, Hashable, Sendable {
    let conversationID: UUID
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
    let hostUnreadCount: Int?
    let vendorUnreadCount: Int?
    let latestMessagePreview: String?
    let latestRequestTitle: String?
    let latestRequestBudgetLabel: String?
    let latestRequestEventDate: Date?
    let latestBookingID: UUID?
    let latestBookingStage: String?

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
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
        case hostUnreadCount = "host_unread_count"
        case vendorUnreadCount = "vendor_unread_count"
        case latestMessagePreview = "latest_message_preview"
        case latestRequestTitle = "latest_request_title"
        case latestRequestBudgetLabel = "latest_request_budget_label"
        case latestRequestEventDate = "latest_request_event_date"
        case latestBookingID = "latest_booking_id"
        case latestBookingStage = "latest_booking_stage"
    }

    init(
        conversationID: UUID,
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
        hostUnreadCount: Int?,
        vendorUnreadCount: Int?,
        latestMessagePreview: String?,
        latestRequestTitle: String?,
        latestRequestBudgetLabel: String?,
        latestRequestEventDate: Date?,
        latestBookingID: UUID?,
        latestBookingStage: String?
    ) {
        self.conversationID = conversationID
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
        self.hostUnreadCount = hostUnreadCount
        self.vendorUnreadCount = vendorUnreadCount
        self.latestMessagePreview = latestMessagePreview
        self.latestRequestTitle = latestRequestTitle
        self.latestRequestBudgetLabel = latestRequestBudgetLabel
        self.latestRequestEventDate = latestRequestEventDate
        self.latestBookingID = latestBookingID
        self.latestBookingStage = latestBookingStage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversationID = try container.decode(UUID.self, forKey: .conversationID)
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
        hostUnreadCount = try container.decodeIfPresent(Int.self, forKey: .hostUnreadCount)
        vendorUnreadCount = try container.decodeIfPresent(Int.self, forKey: .vendorUnreadCount)
        latestMessagePreview = try container.decodeIfPresent(String.self, forKey: .latestMessagePreview)
        latestRequestTitle = try container.decodeIfPresent(String.self, forKey: .latestRequestTitle)
        latestRequestBudgetLabel = try container.decodeIfPresent(String.self, forKey: .latestRequestBudgetLabel)
        latestRequestEventDate = try PostgresDateValueDecoder.decodeIfPresent(forKey: .latestRequestEventDate, from: container)
        latestBookingID = try container.decodeIfPresent(UUID.self, forKey: .latestBookingID)
        latestBookingStage = try container.decodeIfPresent(String.self, forKey: .latestBookingStage)
    }
}
