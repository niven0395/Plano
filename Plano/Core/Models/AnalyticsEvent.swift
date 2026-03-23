import Foundation

enum AnalyticsEventType: String, Sendable {
    case searchImpression = "search_impression"
    case profileView = "profile_view"
    case galleryScroll = "gallery_scroll"
    case socialLinkClick = "social_link_click"
    case vendorSaved = "vendor_saved"
    case vendorUnsaved = "vendor_unsaved"
    case conversationStarted = "conversation_started"
    case bookingRequested = "booking_requested"
    case bookingConfirmed = "booking_confirmed"
    case bookingCompleted = "booking_completed"
    case bookingDeclined = "booking_declined"
    case bookingCancelled = "booking_cancelled"
}

struct AnalyticsEvent: Sendable {
    let eventType: AnalyticsEventType
    let vendorID: UUID
    let eventID: UUID?
    let metadata: [String: String]
    let timestamp: Date

    init(
        eventType: AnalyticsEventType,
        vendorID: UUID,
        eventID: UUID? = nil,
        metadata: [String: String] = [:],
        timestamp: Date = .now
    ) {
        self.eventType = eventType
        self.vendorID = vendorID
        self.eventID = eventID
        self.metadata = metadata
        self.timestamp = timestamp
    }
}
