import Foundation
import OSLog

// MARK: - Message loading, pagination, read receipts, typing, catch-up sync

extension InboxStore {

    func loadMessages(for conversationID: UUID) async {
        guard let index = indexOfConversation(id: conversationID) else { return }

        let thread = conversations[index]
        guard !thread.hasLoadedInitialMessages, !thread.isLoadingMessages else { return }

        conversations[index].isLoadingMessages = true

        if let cacheManager = messageCacheManager {
            do {
                let cachedRecords = try await cacheManager.fetchMessages(conversationID: conversationID)
                if !cachedRecords.isEmpty, let currentIndex = indexOfConversation(id: conversationID) {
                    let attachmentsByMessage = try await attachmentMap(for: cachedRecords, preferServerFallback: false)
                    let cachedMessages = cachedRecords.map { record in
                        makeChatMessage(from: record, attachments: attachmentsByMessage[record.id] ?? [])
                    }
                    conversations[currentIndex].messages = cachedMessages
                    conversations[currentIndex].hasLoadedInitialMessages = true
                    conversations[currentIndex].lastMessagePreviewText = cachedMessages.last?.previewText
                    if let lastDate = cachedRecords.last?.createdAt {
                        lastRealtimeMessageAt[conversationID] = lastDate
                    }
                }
            } catch {
                AppLogger.booking.error("Failed to load cached messages: \(error.localizedDescription, privacy: .public)")
            }
        }

        do {
            let records = try await messagingService.fetchMessages(
                conversationID: conversationID,
                beforeSequence: nil,
                limit: Self.messagesPerPage
            )
            let attachmentsByMessage = try await attachmentMap(for: records)
            applyLatestMessagePage(
                records,
                attachmentsByMessage: attachmentsByMessage,
                to: conversationID,
                hasOlderMessages: records.count >= Self.messagesPerPage
            )
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            guard let currentIndex = indexOfConversation(id: conversationID) else { return }
            conversations[currentIndex].isLoadingMessages = false
            AppLogger.booking.error("Failed to load messages: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadOlderMessages(for conversationID: UUID) async {
        guard let index = indexOfConversation(id: conversationID) else { return }

        let thread = conversations[index]
        guard thread.hasOlderMessages, !thread.isLoadingMessages else { return }

        guard let beforeSequence = thread.messages.compactMap(\.sequenceNumber).min() else {
            conversations[index].hasOlderMessages = false
            return
        }
        conversations[index].isLoadingMessages = true

        do {
            let records = try await messagingService.fetchMessages(
                conversationID: conversationID,
                beforeSequence: beforeSequence,
                limit: Self.messagesPerPage
            )
            let attachmentsByMessage = try await attachmentMap(for: records)
            prependOlderMessagePage(
                records,
                attachmentsByMessage: attachmentsByMessage,
                to: conversationID,
                hasOlderMessages: records.count >= Self.messagesPerPage
            )
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            guard let currentIndex = indexOfConversation(id: conversationID) else { return }
            conversations[currentIndex].isLoadingMessages = false
            AppLogger.booking.error("Failed to load older messages: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Read receipts & typing

    func markConversationRead(_ conversationID: UUID, for role: UserRole, forceRemote: Bool = false) {
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
        persistConversationSnapshotIfNeeded(conversationID)

        if hadUnread || forceRemote {
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
        stopTypingIndicator(for: conversationID, as: role)
        if isArchived(conversationID, for: role) {
            unarchiveConversation(conversationID, for: role)
        }
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
        stopTypingIndicator(for: conversationID, as: role)
        // Re-sending into an archived thread (e.g. after cancelling a booking)
        // should bring the conversation back into the active inbox.
        if isArchived(conversationID, for: role) {
            unarchiveConversation(conversationID, for: role)
        }
        messageSender.sendMessageWithAttachments(body, attachments: attachments, in: conversationID, as: role)
    }

    func signedURL(for storagePath: String) async throws -> URL {
        try await messagingService.signedURL(for: storagePath)
    }

    func sendTypingIndicator(
        for conversationID: UUID,
        as role: UserRole,
        isComposing: Bool
    ) {
        let key = typingKey(for: conversationID, role: role)

        guard isComposing else {
            typingDebounceTimers[key]?.cancel()
            typingDebounceTimers[key] = nil

            if activeTypingKeys.remove(key) != nil {
                realtimeManager?.sendTypingIndicator(
                    conversationID: conversationID,
                    senderRole: role.rawValue,
                    isTyping: false
                )
            }
            return
        }

        typingDebounceTimers[key]?.cancel()
        if activeTypingKeys.insert(key).inserted {
            realtimeManager?.sendTypingIndicator(
                conversationID: conversationID,
                senderRole: role.rawValue,
                isTyping: true
            )
        }

        typingDebounceTimers[key] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.typingDebounceTimers[key] = nil
            guard self?.activeTypingKeys.remove(key) != nil else { return }
            self?.realtimeManager?.sendTypingIndicator(
                conversationID: conversationID,
                senderRole: role.rawValue,
                isTyping: false
            )
        }
    }

    func stopTypingIndicator(for conversationID: UUID, as role: UserRole) {
        sendTypingIndicator(for: conversationID, as: role, isComposing: false)
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
                guard !records.isEmpty else { continue }

                let attachmentsByMessage = (try? await attachmentMap(for: records)) ?? [:]
                let merged = mergeIncomingRecords(
                    records,
                    attachmentsByMessage: attachmentsByMessage,
                    into: conversationID
                )

                if merged > 0 {
                    AppLogger.networking.notice(
                        "Catch-up sync: merged \(merged, privacy: .public) messages for conversation \(conversationID.uuidString.prefix(8), privacy: .public)"
                    )
                }
            }
        }

        conversations.sort { $0.lastActivityAt > $1.lastActivityAt }
    }

    private func typingKey(for conversationID: UUID, role: UserRole) -> String {
        "\(conversationID.uuidString).\(role.rawValue)"
    }
}
