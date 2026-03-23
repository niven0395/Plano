import Foundation
import SwiftData

@Model
final class CachedConversation {
    #Index<CachedConversation>([\.lastActivityAt])
    @Attribute(.unique) var conversationID: UUID
    var vendorID: UUID
    var hostUserID: UUID
    var hostName: String
    var vendorName: String
    var vendorCategory: String
    var eventTitle: String
    var eventDateLabel: String
    var eventContextLine: String
    var stage: String
    var lastActivityAt: Date
    var hostUnreadCount: Int
    var vendorUnreadCount: Int
    var eventID: UUID?

    init(
        conversationID: UUID,
        vendorID: UUID,
        hostUserID: UUID,
        hostName: String,
        vendorName: String,
        vendorCategory: String,
        eventTitle: String,
        eventDateLabel: String,
        eventContextLine: String,
        stage: String,
        lastActivityAt: Date,
        hostUnreadCount: Int,
        vendorUnreadCount: Int,
        eventID: UUID? = nil
    ) {
        self.conversationID = conversationID
        self.vendorID = vendorID
        self.hostUserID = hostUserID
        self.hostName = hostName
        self.vendorName = vendorName
        self.vendorCategory = vendorCategory
        self.eventTitle = eventTitle
        self.eventDateLabel = eventDateLabel
        self.eventContextLine = eventContextLine
        self.stage = stage
        self.lastActivityAt = lastActivityAt
        self.hostUnreadCount = hostUnreadCount
        self.vendorUnreadCount = vendorUnreadCount
        self.eventID = eventID
    }
}

// MARK: - Sendable record for cross-isolation use

struct CachedConversationRecord: Sendable, Identifiable {
    let id: UUID
    let vendorID: UUID
    let hostUserID: UUID
    let hostName: String
    let vendorName: String
    let vendorCategory: String
    let eventTitle: String
    let eventDateLabel: String
    let eventContextLine: String
    let stage: String
    let lastActivityAt: Date
    let hostUnreadCount: Int
    let vendorUnreadCount: Int
    let eventID: UUID?
}

extension CachedConversation {
    func toRecord() -> CachedConversationRecord {
        CachedConversationRecord(
            id: conversationID,
            vendorID: vendorID,
            hostUserID: hostUserID,
            hostName: hostName,
            vendorName: vendorName,
            vendorCategory: vendorCategory,
            eventTitle: eventTitle,
            eventDateLabel: eventDateLabel,
            eventContextLine: eventContextLine,
            stage: stage,
            lastActivityAt: lastActivityAt,
            hostUnreadCount: hostUnreadCount,
            vendorUnreadCount: vendorUnreadCount,
            eventID: eventID
        )
    }
}
