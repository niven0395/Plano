import Foundation
import OSLog

// MARK: - Message loading, pagination, read receipts, typing, catch-up sync

extension InboxStore {

    func loadMessages(for conversationID: UUID) async {
        guard let index = indexOfConversation(id: conversationID) else { return }

        let thread = conversations[index]
        guard !thread.hasLoadedInitialMessages, !thread.isLoadingMessages else { return }

        conversations[index].isLoadingMessages = true

        // Load from local cache first for instant UI
        if let cacheManager = messageCacheManager {
            do {
                let cachedRecords = try await cacheManager.fetchMessages(conversationID: conversationID)
                if !cachedRecords.isEmpty, let currentIndex = indexOfConversation(id: conversationID) {
                    let cachedMessages = cachedRecords.map { makeChatMessage(from: $0) }
                    conversations[currentIndex].messages = cachedMessages
                    conversations[currentIndex].hasLoadedInitialMessages = true
                    if let lastDate = cachedRecords.last?.createdAt {
                        lastRealtimeMessageAt[conversationID] = lastDate
                    }
                }
            } catch {
                AppLogger.booking.error("Failed to load cached messages: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Fetch from server in background and merge
        do {
            let records = try await messagingService.fetchMessages(
                conversationID: conversationID,
                before: nil,
                limit: Self.messagesPerPage
            )

            var messages = records.map { makeChatMessage(from: $0) }

            let attachmentMessageIDs = records.filter { $0.kind == "attachment" }.map(\.id)
            if !attachmentMessageIDs.isEmpty {
                let attachmentRecords = try await messagingService.fetchAttachments(messageIDs: attachmentMessageIDs)
                let attachmentsByMessage = Dictionary(grouping: attachmentRecords, by: \.messageID)
                for i in messages.indices {
                    if let msgAttachments = attachmentsByMessage[messages[i].id] {
                        messages[i].attachments = msgAttachments.map { $0.toAttachment() }
                    }
                }

                // Cache attachments
                if let cacheManager = messageCacheManager {
                    Task { try? await cacheManager.upsertAttachments(attachmentRecords) }
                }
            }

            guard let currentIndex = indexOfConversation(id: conversationID) else { return }
            conversations[currentIndex].messages = messages
            conversations[currentIndex].hasLoadedInitialMessages = true
            conversations[currentIndex].hasOlderMessages = records.count >= Self.messagesPerPage
            conversations[currentIndex].isLoadingMessages = false

            if let lastDate = records.last?.createdAt {
                lastRealtimeMessageAt[conversationID] = lastDate
            }

            // Write to local cache in background
            if let cacheManager = messageCacheManager {
                Task { try? await cacheManager.upsertMessages(records) }
            }
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            guard let currentIndex = indexOfConversation(id: conversationID) else { return }
            // If we already have cached messages, mark as loaded despite network failure
            if conversations[currentIndex].hasLoadedInitialMessages {
                conversations[currentIndex].isLoadingMessages = false
            } else {
                conversations[currentIndex].isLoadingMessages = false
            }
            AppLogger.booking.error("Failed to load messages: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadOlderMessages(for conversationID: UUID) async {
        guard let index = indexOfConversation(id: conversationID) else { return }

        let thread = conversations[index]
        guard thread.hasOlderMessages, !thread.isLoadingMessages else { return }

        let cursor = thread.messages.first?.sentAt
        conversations[index].isLoadingMessages = true

        do {
            let records = try await messagingService.fetchMessages(
                conversationID: conversationID,
                before: cursor,
                limit: Self.messagesPerPage
            )

            let olderMessages = records.map { makeChatMessage(from: $0) }

            guard let currentIndex = indexOfConversation(id: conversationID) else { return }
            conversations[currentIndex].messages.insert(contentsOf: olderMessages, at: 0)
            conversations[currentIndex].hasOlderMessages = records.count >= Self.messagesPerPage
            conversations[currentIndex].isLoadingMessages = false
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            guard let currentIndex = indexOfConversation(id: conversationID) else { return }
            conversations[currentIndex].isLoadingMessages = false
            AppLogger.booking.error("Failed to load older messages: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Read receipts & typing

    func markConversationRead(_ conversationID: UUID, for role: UserRole) {
        guard let index = indexOfConversation(id: conversationID) else { return }

        var thread = conversations[index]
        let hadUnread: Bool
        switch role {
        case .host:
            hadUnread = thread.hostUnreadCount > 0
            thread.hostUnreadCount = 0
        case .vendor:
            hadUnread = thread.vendorUnreadCount > 0
            thread.vendorUnreadCount = 0
        }
        conversations[index] = thread

        if hadUnread {
            Task {
                try? await messagingService.markMessagesRead(
                    conversationID: conversationID,
                    role: role.rawValue
                )
            }
        }
    }

    @discardableResult
    func sendDraft(in conversationID: UUID, as role: UserRole) -> Bool {
        let messageBody = draft(for: conversationID, role: role)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !messageBody.isEmpty else { return false }

        updateDraft("", for: conversationID, role: role)
        messageSender.sendMessage(messageBody, in: conversationID, as: role)
        return true
    }

    func isCounterpartTyping(in conversationID: UUID, for role: UserRole) -> Bool {
        typingSenders[conversationID]?.userRole == role.counterpart
    }

    // MARK: - Messaging (delegates to ConversationMessageSender)

    func sendMessageWithAttachments(
        _ body: String,
        attachments: [PendingAttachment],
        in conversationID: UUID,
        as role: UserRole
    ) {
        messageSender.sendMessageWithAttachments(body, attachments: attachments, in: conversationID, as: role)
    }

    func signedURL(for storagePath: String) async throws -> URL {
        try await messagingService.signedURL(for: storagePath)
    }

    func sendTypingIndicator(for conversationID: UUID, as role: UserRole) {
        let key = conversationID
        typingDebounceTimers[key]?.cancel()
        realtimeManager?.sendTypingIndicator(conversationID: conversationID, senderRole: role.rawValue)

        typingDebounceTimers[key] = Task {
            try? await Task.sleep(for: .seconds(2))
        }
    }

    func retryFailedMessage(clientID: UUID, in conversationID: UUID, as role: UserRole) {
        guard let index = indexOfConversation(id: conversationID) else { return }
        guard let msgIndex = conversations[index].messages.firstIndex(where: { $0.clientID == clientID }) else { return }

        let message = conversations[index].messages[msgIndex]
        messageSender.retryFailedMessage(clientID: clientID, body: message.body, in: conversationID, as: role)
    }

    // MARK: - Catch-up sync after reconnection

    func catchUpAfterReconnect() async {
        let loadedConversations = conversations.filter(\.hasLoadedInitialMessages)
        guard !loadedConversations.isEmpty else { return }

        AppLogger.networking.notice("Catch-up sync: checking \(loadedConversations.count, privacy: .public) conversations")

        await withTaskGroup(of: (UUID, [MessageRecord]).self) { group in
            for thread in loadedConversations {
                let conversationID = thread.id

                // Prefer sequence-based catch-up when available
                let lastSequence = thread.messages.compactMap(\.sequenceNumber).max()

                if let seq = lastSequence {
                    group.addTask { [messagingService] in
                        do {
                            let records = try await messagingService.fetchMessagesSinceSequence(
                                conversationID: conversationID,
                                afterSequence: seq,
                                limit: 100
                            )
                            return (conversationID, records)
                        } catch {
                            return (conversationID, [])
                        }
                    }
                } else {
                    // Fallback to timestamp-based catch-up
                    let since = lastRealtimeMessageAt[conversationID]
                        ?? thread.messages.last?.sentAt
                        ?? thread.lastActivityAt

                    group.addTask { [messagingService] in
                        do {
                            let records = try await messagingService.fetchMessagesSince(
                                conversationID: conversationID,
                                after: since,
                                limit: 100
                            )
                            return (conversationID, records)
                        } catch {
                            return (conversationID, [])
                        }
                    }
                }
            }

            for await (conversationID, records) in group {
                guard !records.isEmpty,
                      let index = indexOfConversation(id: conversationID) else { continue }

                var merged = 0
                for record in records {
                    // Deduplicate by id and clientID
                    if conversations[index].messages.contains(where: { $0.id == record.id }) {
                        continue
                    }
                    if let clientID = record.clientID,
                       conversations[index].messages.contains(where: { $0.clientID == clientID }) {
                        continue
                    }

                    let message = makeChatMessage(from: record)
                    conversations[index].messages.append(message)
                    lastRealtimeMessageAt[conversationID] = record.createdAt
                    merged += 1
                }

                if merged > 0 {
                    conversations[index].lastActivityAt = records.last?.createdAt ?? conversations[index].lastActivityAt
                    AppLogger.networking.notice(
                        "Catch-up sync: merged \(merged, privacy: .public) messages for conversation \(conversationID.uuidString.prefix(8), privacy: .public)"
                    )
                }
            }
        }

        conversations.sort { $0.lastActivityAt > $1.lastActivityAt }
    }
}
