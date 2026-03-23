import Foundation
import OSLog

// MARK: - Realtime handlers, mutation helpers, data helpers

extension InboxStore {

    // MARK: - Realtime handlers

    func handleRealtimeMessage(_ record: MessageRecord) {
        guard let index = indexOfConversation(id: record.conversationID) else { return }
        let thread = conversations[index]

        if let clientID = record.clientID,
           thread.messages.contains(where: { $0.clientID == clientID }) {
            // Update tracking even for deduped messages
            lastRealtimeMessageAt[record.conversationID] = record.createdAt
            return
        }

        if thread.messages.contains(where: { $0.id == record.id }) {
            lastRealtimeMessageAt[record.conversationID] = record.createdAt
            return
        }

        let message = makeChatMessage(from: record)

        conversations[index].messages.append(message)
        conversations[index].lastActivityAt = record.createdAt
        lastRealtimeMessageAt[record.conversationID] = record.createdAt
        conversations.sort { $0.lastActivityAt > $1.lastActivityAt }

        // Cache the incoming message
        if let cacheManager = messageCacheManager {
            Task { try? await cacheManager.upsertMessage(record) }
        }

        let role = sessionStore.currentRole
        if isArchived(record.conversationID, for: role) {
            unarchiveConversation(record.conversationID, for: role)
        }

        typingSenders.removeValue(forKey: record.conversationID)

        // Mark the received message as delivered (sender will see checkmark progression)
        let senderRole = ChatMessageSender(rawValue: record.senderRole)
        if senderRole?.userRole != sessionStore.currentRole {
            Task {
                try? await messagingService.markMessageDelivered(messageID: record.id)
            }
        }
    }

    func handleRealtimeMessageStatusUpdate(messageID: UUID, status: String) {
        let deliveryStatus: MessageDeliveryStatus
        switch status {
        case "delivered":
            deliveryStatus = .delivered
        case "read":
            deliveryStatus = .read
        default:
            return
        }

        for i in conversations.indices {
            if let msgIndex = conversations[i].messages.firstIndex(where: { $0.id == messageID }) {
                let currentStatus = conversations[i].messages[msgIndex].status
                // Only upgrade status, never downgrade
                if currentStatus == .sending || currentStatus == .sent ||
                   (currentStatus == .delivered && deliveryStatus == .read) {
                    conversations[i].messages[msgIndex].status = deliveryStatus
                }
                return
            }
        }
    }

    func handleRealtimeConversationUpdate(_ record: ConversationRecord) {
        guard let index = indexOfConversation(id: record.id) else { return }

        let previousStage = conversations[index].stage
        let newStage = BookingStage.fromDatabaseValue(record.stage)

        conversations[index].stage = newStage
        conversations[index].lastActivityAt = record.lastActivityAt
        conversations[index].hostUnreadCount = record.hostUnreadCount ?? conversations[index].hostUnreadCount
        conversations[index].vendorUnreadCount = record.vendorUnreadCount ?? conversations[index].vendorUnreadCount
        conversations.sort { $0.lastActivityAt > $1.lastActivityAt }

        if previousStage != newStage {
            onStageChanged?()
        }

        if newStage == .paymentRequested, previousStage != .paymentRequested {
            Task { [weak self] in
                await self?.refreshPaymentRequest(for: record.id)
            }
        } else if newStage == .paid, previousStage != .paid {
            Task { [weak self] in
                await self?.refreshPaymentRequest(for: record.id)
            }
        }
    }

    func refreshPaymentRequest(for conversationID: UUID) async {
        do {
            let bookings = try await bookingService.fetchBookings(conversationIDs: [conversationID])
            guard let booking = bookings.first,
                  let amountCents = booking.paymentRequestedAmountCents,
                  let index = indexOfConversation(id: conversationID) else { return }

            let status: PaymentRequestStatus = booking.paymentConfirmedAt != nil ? .paid : .pending
            conversations[index].paymentRequest = PaymentRequest(
                amountCents: amountCents,
                note: booking.paymentRequestNote ?? "",
                requestedAt: booking.paymentRequestedAt,
                status: status,
                paymentType: booking.paymentType.flatMap { PaymentType(rawValue: $0) } ?? .deposit
            )
        } catch {
            AppLogger.booking.error("Failed to refresh payment request for \(conversationID): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Offline handlers

    func handleOfflineMessageSent(conversationID: UUID, clientID: UUID, record: MessageRecord) {
        replaceOptimisticMessage(
            clientID: clientID,
            in: conversationID,
            with: ChatMessage(
                id: record.id,
                sender: ChatMessageSender(rawValue: record.senderRole) ?? .host,
                body: record.body,
                sentAt: record.createdAt,
                status: .sent,
                clientID: clientID
            )
        )
    }

    func handleOfflineMessageFailed(conversationID: UUID, clientID: UUID) {
        updateMessageStatus(clientID: clientID, in: conversationID, to: .failed)
    }

    // MARK: - Mutation helpers

    func replaceOptimisticMessage(clientID: UUID, in conversationID: UUID, with persistedMessage: ChatMessage) {
        updateConversation(conversationID) { thread in
            if let index = thread.messages.firstIndex(where: { $0.clientID == clientID }) {
                thread.messages[index] = persistedMessage
            }
            thread.lastActivityAt = persistedMessage.sentAt
        }
    }

    func updateMessageStatus(clientID: UUID, in conversationID: UUID, to status: MessageDeliveryStatus) {
        updateConversation(conversationID) { thread in
            if let index = thread.messages.firstIndex(where: { $0.clientID == clientID }) {
                thread.messages[index].status = status
            }
        }
    }

    func appendMessage(
        _ message: ChatMessage,
        to conversationID: UUID,
        incrementUnreadFor unreadRole: UserRole?
    ) {
        updateConversation(conversationID) { thread in
            thread.messages.append(message)
            thread.lastActivityAt = message.sentAt

            switch unreadRole {
            case .host:
                thread.hostUnreadCount += 1
            case .vendor:
                thread.vendorUnreadCount += 1
            case nil:
                break
            }
        }
    }

    // MARK: - Query internals

    func scopedConversations(for role: UserRole) -> [ConversationThread] {
        switch role {
        case .host:
            guard let hostUserID = sessionStore.currentUserID else { return [] }
            return conversations.filter { $0.hostUserID == hostUserID }
        case .vendor:
            guard let vendorID = sessionStore.currentUserID else { return [] }
            return conversations.filter { $0.vendorID == vendorID }
        }
    }

    func matchesCurrentFilter(_ thread: ConversationThread, role: UserRole) -> Bool {
        let archived = isArchived(thread.id, for: role)

        if filter == .archived {
            return archived
        }

        if archived {
            return false
        }

        if thread.stage.isTerminal, thread.unreadCount(for: role) == 0 {
            return false
        }

        return switch filter {
        case .all:
            true
        case .unread:
            thread.unreadCount(for: role) > 0
        case .actionNeeded:
            thread.stage.isActionable && !thread.stage.isConfirmed
        case .archived:
            false
        }
    }

    func sender(for role: UserRole) -> ChatMessageSender {
        switch role {
        case .host:
            .host
        case .vendor:
            .vendor
        }
    }

    func indexOfConversation(id: UUID) -> Int? {
        conversations.firstIndex(where: { $0.id == id })
    }

    func updateConversation(_ conversationID: UUID, mutate: (inout ConversationThread) -> Void) {
        guard let index = indexOfConversation(id: conversationID) else { return }

        var thread = conversations[index]
        mutate(&thread)
        conversations[index] = thread
        conversations.sort { $0.lastActivityAt > $1.lastActivityAt }
    }

    func restoreConversation(_ snapshot: ConversationThread) {
        if let index = conversations.firstIndex(where: { $0.id == snapshot.id }) {
            conversations[index] = snapshot
            conversations.sort { $0.lastActivityAt > $1.lastActivityAt }
        }
    }

    func fetchMessageRecords(for conversationIDs: [UUID]) async throws -> [MessageRecord] {
        guard !conversationIDs.isEmpty else { return [] }

        var collected: [MessageRecord] = []
        try await withThrowingTaskGroup(of: [MessageRecord].self) { group in
            for conversationID in conversationIDs {
                group.addTask { [bookingService] in
                    try await bookingService.fetchMessages(conversationID: conversationID)
                }
            }

            for try await result in group {
                collected.append(contentsOf: result)
            }
        }

        return collected.sorted { $0.createdAt < $1.createdAt }
    }

    func latestBookingRequests(_ records: [BookingRequestRecord]) -> [UUID: BookingRequestRecord] {
        Dictionary(grouping: records, by: \.conversationID)
            .compactMapValues(\.first)
    }

    func latestBookings(_ records: [BookingRecord]) -> [UUID: BookingRecord] {
        Dictionary(grouping: records, by: \.conversationID)
            .compactMapValues(\.first)
    }

    func loadVendorProfiles(for vendorIDs: Set<UUID>) async {
        let missingVendorIDs = vendorIDs.filter { vendorProfilesByID[$0] == nil }
        guard !missingVendorIDs.isEmpty else { return }

        await withTaskGroup(of: VendorProfile?.self) { group in
            for vendorID in missingVendorIDs {
                group.addTask { [vendorProfileService] in
                    do {
                        guard let record = try await vendorProfileService.fetchPublicVendorProfile(vendorID: vendorID) else {
                            return nil
                        }

                        async let galleryImages = vendorProfileService.fetchGalleryImages(vendorID: vendorID)
                        async let serviceItems = vendorProfileService.fetchServiceItems(vendorID: vendorID)
                        return record.makeVendorProfile(
                            serviceItems: try await serviceItems,
                            galleryImages: try await galleryImages
                        )
                    } catch {
                        return nil
                    }
                }
            }

            for await vendor in group {
                if let vendor {
                    vendorProfilesByID[vendor.id] = vendor
                }
            }
        }
    }

    func ensureConversationIndex(for conversationID: UUID) async -> Int? {
        if let index = indexOfConversation(id: conversationID) {
            return index
        }

        _ = await ensureConversationLoaded(conversationID, for: sessionStore.currentRole)
        return indexOfConversation(id: conversationID)
    }

    func refreshVendorDateConflicts(for threads: [ConversationThread]) async {
        var refreshedConflicts: [UUID: [DateConflict]] = [:]

        await withTaskGroup(of: (UUID, [DateConflict]).self) { group in
            for thread in threads {
                guard let eventDate = thread.eventDate else { continue }
                let conversationID = thread.id
                let vendorID = thread.vendorID

                group.addTask { [bookingService] in
                    do {
                        let conflicts = try await bookingService.checkVendorDateConflicts(
                            vendorID: vendorID,
                            eventDate: eventDate
                        )
                        .filter { $0.conversationID != conversationID }
                        return (conversationID, conflicts)
                    } catch {
                        return (conversationID, [])
                    }
                }
            }

            for await (conversationID, conflicts) in group {
                refreshedConflicts[conversationID] = conflicts
            }
        }

        dateConflictsByConversation = refreshedConflicts
    }

    func makeChatMessage(from record: MessageRecord) -> ChatMessage {
        let sender: ChatMessageSender
        switch record.senderRole {
        case "host":
            sender = .host
        case "vendor":
            sender = .vendor
        default:
            sender = .system
        }

        let kind: ChatMessageKind
        switch record.kind {
        case "payment_request":
            kind = .paymentRequest
        case "attachment":
            kind = .attachment
        case "system", "booking_request", "quote", "payment_receipt":
            kind = .system
        default:
            kind = .text
        }

        let deliveryStatus: MessageDeliveryStatus
        switch record.status {
        case "read":
            deliveryStatus = .read
        case "delivered":
            deliveryStatus = .delivered
        case "sending":
            deliveryStatus = .sending
        default:
            deliveryStatus = .sent
        }

        return ChatMessage(
            id: record.id,
            sender: sender,
            body: record.body,
            sentAt: record.createdAt,
            kind: kind,
            status: deliveryStatus,
            clientID: record.clientID,
            sequenceNumber: record.sequenceNumber
        )
    }
}
