import Foundation

nonisolated struct ConversationSummaryRecord: Codable, Hashable, Sendable {
    let conversationID: UUID
    let eventID: UUID?
    let vendorID: UUID
    let hostID: UUID
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
        case latestRequestTitle = "latest_request_title"
        case latestRequestBudgetLabel = "latest_request_budget_label"
        case latestRequestEventDate = "latest_request_event_date"
        case latestBookingID = "latest_booking_id"
        case latestBookingStage = "latest_booking_stage"
    }
}
