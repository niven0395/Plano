import Foundation
import OSLog
import SwiftData

actor MessageCacheManager {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Messages

    func upsertMessage(_ record: MessageRecord) throws {
        let context = ModelContext(modelContainer)
        let messageID = record.id

        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.messageID == messageID }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: record)
        } else {
            let cached = CachedMessage(
                messageID: record.id,
                conversationID: record.conversationID,
                senderRole: record.senderRole,
                body: record.body,
                kind: record.kind,
                createdAt: record.createdAt,
                sequenceNumber: record.sequenceNumber,
                status: record.status ?? "sent",
                clientID: record.clientID
            )
            context.insert(cached)
        }

        try context.save()
    }

    func upsertMessages(_ records: [MessageRecord]) throws {
        guard !records.isEmpty else { return }
        let context = ModelContext(modelContainer)

        let ids = records.map(\.id)
        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate<CachedMessage> { ids.contains($0.messageID) }
        )
        let existing = try context.fetch(descriptor)
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.messageID, $0) })

        for record in records {
            if let cached = existingByID[record.id] {
                cached.update(from: record)
            } else {
                let cached = CachedMessage(
                    messageID: record.id,
                    conversationID: record.conversationID,
                    senderRole: record.senderRole,
                    body: record.body,
                    kind: record.kind,
                    createdAt: record.createdAt,
                    sequenceNumber: record.sequenceNumber,
                    status: record.status ?? "sent",
                    clientID: record.clientID
                )
                context.insert(cached)
            }
        }

        try context.save()
    }

    func fetchMessages(conversationID: UUID, limit: Int = 30) throws -> [MessageRecord] {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.conversationID == conversationID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let results = try context.fetch(descriptor)
        return results.reversed().map { $0.toMessageRecord() }
    }

    func updateMessageStatus(messageID: UUID, status: String) throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.messageID == messageID }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.status = status
            try context.save()
        }
    }

    // MARK: - Conversations

    func upsertConversation(_ thread: ConversationThread) throws {
        let context = ModelContext(modelContainer)
        let conversationID = thread.id

        let descriptor = FetchDescriptor<CachedConversation>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.vendorID = thread.vendorID
            existing.hostUserID = thread.hostUserID
            existing.hostName = thread.hostName
            existing.vendorName = thread.vendorName
            existing.vendorCategory = thread.vendorCategory.rawValue
            existing.eventTitle = thread.eventTitle
            existing.eventDateLabel = thread.eventDateLabel
            existing.eventContextLine = thread.eventContextLine
            existing.stage = thread.stage.rawValue
            existing.lastActivityAt = thread.lastActivityAt
            existing.lastMessagePreviewText = thread.lastMessagePreview
            existing.hostUnreadCount = thread.hostUnreadCount
            existing.vendorUnreadCount = thread.vendorUnreadCount
            existing.eventID = thread.eventID
        } else {
            let cached = CachedConversation(
                conversationID: thread.id,
                vendorID: thread.vendorID,
                hostUserID: thread.hostUserID,
                hostName: thread.hostName,
                vendorName: thread.vendorName,
                vendorCategory: thread.vendorCategory.rawValue,
                eventTitle: thread.eventTitle,
                eventDateLabel: thread.eventDateLabel,
                eventContextLine: thread.eventContextLine,
                stage: thread.stage.rawValue,
                lastActivityAt: thread.lastActivityAt,
                lastMessagePreviewText: thread.lastMessagePreview,
                hostUnreadCount: thread.hostUnreadCount,
                vendorUnreadCount: thread.vendorUnreadCount,
                eventID: thread.eventID
            )
            context.insert(cached)
        }

        try context.save()
    }

    func fetchCachedConversations() throws -> [CachedConversationRecord] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedConversation>(
            sortBy: [SortDescriptor(\.lastActivityAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toRecord() }
    }

    // MARK: - Attachments

    func upsertAttachments(_ records: [MessageAttachmentRecord]) throws {
        guard !records.isEmpty else { return }
        let context = ModelContext(modelContainer)

        let ids = records.map(\.id)
        let descriptor = FetchDescriptor<CachedAttachment>(
            predicate: #Predicate<CachedAttachment> { ids.contains($0.attachmentID) }
        )
        let existingIDs = Set(try context.fetch(descriptor).map(\.attachmentID))

        for record in records where !existingIDs.contains(record.id) {
            let cached = CachedAttachment(
                attachmentID: record.id,
                messageID: record.messageID,
                storagePath: record.storagePath,
                fileName: record.fileName,
                mimeType: record.mimeType,
                fileSizeBytes: record.fileSizeBytes,
                width: record.width,
                height: record.height,
                thumbnailPath: record.thumbnailPath,
                createdAt: record.createdAt
            )
            context.insert(cached)
        }

        try context.save()
    }

    func fetchAttachments(messageIDs: [UUID]) throws -> [MessageAttachmentRecord] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedAttachment>(
            predicate: #Predicate { messageIDs.contains($0.messageID) }
        )
        return try context.fetch(descriptor).map { cached in
            MessageAttachmentRecord(
                id: cached.attachmentID,
                messageID: cached.messageID,
                storagePath: cached.storagePath,
                fileName: cached.fileName,
                mimeType: cached.mimeType,
                fileSizeBytes: cached.fileSizeBytes,
                width: cached.width,
                height: cached.height,
                thumbnailPath: cached.thumbnailPath,
                createdAt: cached.createdAt
            )
        }
    }

    // MARK: - Cleanup

    func deleteMessagesForConversation(_ conversationID: UUID) throws {
        let context = ModelContext(modelContainer)
        try context.delete(model: CachedMessage.self, where: #Predicate {
            $0.conversationID == conversationID
        })
        try context.save()
    }

    func deleteAll() throws {
        let context = ModelContext(modelContainer)
        try context.delete(model: CachedMessage.self)
        try context.delete(model: CachedConversation.self)
        try context.delete(model: CachedAttachment.self)
        try context.save()
    }
}
