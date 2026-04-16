import Foundation
import OSLog

// MARK: - Realtime handlers, mutation helpers, data helpers

extension InboxStore {

    // MARK: - Realtime handlers

    func handleRealtimeMessage(_ record: MessageRecord) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard await ensureConversationIndex(for: record.conversationID) != nil else { return }

            let attachmentsByMessage = (try? await attachmentMap(for: [record])) ?? [:]
            _ = mergeIncomingRecords(
                [record],
                attachmentsByMessage: attachmentsByMessage,
                into: record.conversationID
            )

            let role = sessionStore.currentRole
            if isArchived(record.conversationID, for: role) {
                unarchiveConversation(record.conversationID, for: role)
            }

            typingSenders.removeValue(forKey: record.conversationID)

            let senderRole = ChatMessageSender(rawValue: record.senderRole)
            if senderRole?.userRole != role {
                Task {
                    try? await self.messagingService.markMessageDelivered(messageID: record.id)
                }

                if isActiveConversation(record.conversationID, for: role) {
                    markConversationRead(record.conversationID, for: role, forceRemote: true)
                }
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
                if let cacheManager = messageCacheManager {
                    Task { try? await cacheManager.updateMessageStatus(messageID: messageID, status: status) }
                }
                return
            }
        }
    }

    func handleRealtimeConversationUpdate(_ record: ConversationRecord) {
        guard let index = indexOfConversation(id: record.id) else {
            Task { [weak self] in
                guard let self else { return }
                await self.loadConversations(for: self.sessionStore.currentRole)
            }
            return
        }

        let previousStage = conversations[index].stage
        let newStage = BookingStage.fromDatabaseValue(record.stage)

        conversations[index].stage = newStage
        conversations[index].lastActivityAt = record.lastActivityAt
        conversations[index].hostUnreadCount = isActiveConversation(record.id, for: .host) ? 0 : (record.hostUnreadCount ?? conversations[index].hostUnreadCount)
        conversations[index].vendorUnreadCount = isActiveConversation(record.id, for: .vendor) ? 0 : (record.vendorUnreadCount ?? conversations[index].vendorUnreadCount)
        conversations.sort { $0.lastActivityAt > $1.lastActivityAt }
        persistConversationSnapshotIfNeeded(record.id)

        if previousStage != newStage {
            onStageChanged?()

            if previousStage.isTerminal && !newStage.isTerminal {
                let role = sessionStore.currentRole
                if isArchived(record.id, for: role) {
                    unarchiveConversation(record.id, for: role)
                }
            }
        }

        // Realtime updates don't carry all booking metadata; reload to resolve it.
        if previousStage != newStage,
           [BookingStage.paymentRequested, .paid, .cancellationRequested, .cancelled].contains(newStage) {
            Task { [weak self] in
                guard let self else { return }
                await loadConversations(for: sessionStore.currentRole)
            }
        }

        if previousStage != newStage,
           [BookingStage.paymentRequested, .paid, .cancellationRequested].contains(newStage) {
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

    func handleOfflineMessageSent(conversationID: UUID, clientID: UUID, record: MessageSendResult) {
        replaceOptimisticMessage(clientID: clientID, in: conversationID, with: record)
    }

    func handleOfflineMessageFailed(conversationID: UUID, clientID: UUID) {
        updateMessageStatus(clientID: clientID, in: conversationID, to: .failed)
    }

    // MARK: - Mutation helpers

    func replaceOptimisticMessage(clientID: UUID, in conversationID: UUID, with result: MessageSendResult) {
        let attachments = result.attachments.map { $0.toAttachment() }
        let persistedMessage = makeChatMessage(from: result.message, attachments: attachments)

        updateConversation(conversationID) { thread in
            if let index = thread.messages.firstIndex(where: { $0.clientID == clientID }) {
                thread.messages[index] = mergeMessage(thread.messages[index], with: persistedMessage)
            } else if let index = thread.messages.firstIndex(where: { $0.id == persistedMessage.id }) {
                thread.messages[index] = mergeMessage(thread.messages[index], with: persistedMessage)
            } else {
                thread.messages.append(persistedMessage)
            }

            refreshMessageDerivedState(for: &thread)
        }

        persistMessagePage(
            [result.message],
            conversationID: conversationID,
            attachmentRecords: result.attachments
        )
    }

    func updateMessageStatus(clientID: UUID, in conversationID: UUID, to status: MessageDeliveryStatus) {
        updateConversation(conversationID) { thread in
            if let index = thread.messages.firstIndex(where: { $0.clientID == clientID }) {
                thread.messages[index].status = status
            }
        }
        persistConversationSnapshotIfNeeded(conversationID)
    }

    func appendMessage(
        _ message: ChatMessage,
        to conversationID: UUID,
        incrementUnreadFor unreadRole: UserRole?
    ) {
        updateConversation(conversationID) { thread in
            thread.messages.append(message)
            refreshMessageDerivedState(for: &thread)

            switch unreadRole {
            case .host:
                thread.hostUnreadCount += 1
            case .vendor:
                thread.vendorUnreadCount += 1
            case nil:
                break
            }
        }
        persistConversationSnapshotIfNeeded(conversationID)
    }

    func applyLatestMessagePage(
        _ records: [MessageRecord],
        attachmentsByMessage: [UUID: [MessageAttachment]],
        to conversationID: UUID,
        hasOlderMessages: Bool
    ) {
        guard let currentIndex = indexOfConversation(id: conversationID) else { return }

        let existingLocalMessages = unresolvedLocalMessages(
            from: conversations[currentIndex],
            excluding: records
        )
        let serverMessages = records.map { record in
            makeChatMessage(from: record, attachments: attachmentsByMessage[record.id] ?? [])
        }

        var thread = conversations[currentIndex]
        thread.messages = sortedMessages(serverMessages + existingLocalMessages)
        thread.hasLoadedInitialMessages = true
        thread.hasOlderMessages = hasOlderMessages
        thread.isLoadingMessages = false
        refreshMessageDerivedState(for: &thread)
        conversations[currentIndex] = thread

        if let lastDate = records.last?.createdAt {
            lastRealtimeMessageAt[conversationID] = lastDate
        }

        persistMessagePage(records, conversationID: conversationID)
    }

    func prependOlderMessagePage(
        _ records: [MessageRecord],
        attachmentsByMessage: [UUID: [MessageAttachment]],
        to conversationID: UUID,
        hasOlderMessages: Bool
    ) {
        updateConversation(conversationID) { thread in
            let olderMessages = records.map { record in
                makeChatMessage(from: record, attachments: attachmentsByMessage[record.id] ?? [])
            }
            thread.messages = deduplicatedMessages(olderMessages + thread.messages)
            thread.hasOlderMessages = hasOlderMessages
            thread.isLoadingMessages = false
            refreshMessageDerivedState(for: &thread)
        }

        persistMessagePage(records, conversationID: conversationID)
    }

    func attachmentMap(
        for records: [MessageRecord],
        preferServerFallback: Bool = true
    ) async throws -> [UUID: [MessageAttachment]] {
        let attachmentMessageIDs = records.filter { $0.kind == "attachment" }.map(\.id)
        guard !attachmentMessageIDs.isEmpty else { return [:] }

        var attachmentsByMessage: [UUID: [MessageAttachment]] = [:]
        if let cacheManager = messageCacheManager {
            let cachedAttachmentRecords = try await cacheManager.fetchAttachments(messageIDs: attachmentMessageIDs)
            attachmentsByMessage = Dictionary(
                grouping: cachedAttachmentRecords.map { ($0.messageID, $0.toAttachment()) },
                by: \.0
            )
            .mapValues { $0.map { $0.1 } }
        }

        guard preferServerFallback else {
            return attachmentsByMessage.filter { !$0.value.isEmpty }
        }

        let missingMessageIDs = attachmentMessageIDs.filter {
            attachmentsByMessage[$0]?.isEmpty ?? true
        }

        guard !missingMessageIDs.isEmpty else {
            return attachmentsByMessage.filter { !$0.value.isEmpty }
        }

        let attachmentRecords = try await messagingService.fetchAttachments(messageIDs: missingMessageIDs)
        if let cacheManager = messageCacheManager, !attachmentRecords.isEmpty {
            Task { try? await cacheManager.upsertAttachments(attachmentRecords) }
        }

        let fetched = Dictionary(
            grouping: attachmentRecords.map { ($0.messageID, $0.toAttachment()) },
            by: \.0
        )
        .mapValues { $0.map { $0.1 } }
        for messageID in missingMessageIDs {
            attachmentsByMessage[messageID] = fetched[messageID] ?? []
        }

        return attachmentsByMessage.filter { !$0.value.isEmpty }
    }

    @discardableResult
    func mergeIncomingRecords(
        _ records: [MessageRecord],
        attachmentsByMessage: [UUID: [MessageAttachment]],
        into conversationID: UUID
    ) -> Int {
        guard let index = indexOfConversation(id: conversationID) else { return 0 }

        var thread = conversations[index]
        var mergedCount = 0

        for record in records.sorted(by: messageRecordSort) {
            let incoming = makeChatMessage(from: record, attachments: attachmentsByMessage[record.id] ?? [])

            if let clientID = record.clientID,
               let existingIndex = thread.messages.firstIndex(where: { $0.clientID == clientID }) {
                thread.messages[existingIndex] = mergeMessage(thread.messages[existingIndex], with: incoming)
                mergedCount += 1
                continue
            }

            if let existingIndex = thread.messages.firstIndex(where: { $0.id == record.id }) {
                thread.messages[existingIndex] = mergeMessage(thread.messages[existingIndex], with: incoming)
                mergedCount += 1
                continue
            }

            thread.messages.append(incoming)
            mergedCount += 1
        }

        guard mergedCount > 0 else {
            if let lastDate = records.last?.createdAt {
                lastRealtimeMessageAt[conversationID] = lastDate
            }
            return 0
        }

        refreshMessageDerivedState(for: &thread)
        conversations[index] = thread
        if let lastDate = records.last?.createdAt {
            lastRealtimeMessageAt[conversationID] = lastDate
        }

        persistMessagePage(records, conversationID: conversationID)
        if isActiveConversation(conversationID, for: sessionStore.currentRole),
           records.contains(where: { ChatMessageSender(rawValue: $0.senderRole)?.userRole == sessionStore.currentRole.counterpart }) {
            markConversationRead(conversationID, for: sessionStore.currentRole, forceRemote: true)
        }
        return mergedCount
    }

    func refreshMessageDerivedState(for thread: inout ConversationThread) {
        thread.messages = sortedMessages(thread.messages)
        if let lastMessage = thread.messages.last {
            thread.lastActivityAt = max(thread.lastActivityAt, lastMessage.sentAt)
            thread.lastMessagePreviewText = lastMessage.previewText
        }
    }

    func persistMessagePage(
        _ records: [MessageRecord],
        conversationID: UUID,
        attachmentRecords: [MessageAttachmentRecord] = []
    ) {
        guard let cacheManager = messageCacheManager else { return }
        let thread = conversations.first(where: { $0.id == conversationID })

        Task {
            do {
                try await cacheManager.upsertMessages(records)
            } catch {
                AppLogger.app.error("Cache upsertMessages failed (conversation=\(conversationID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            }
            if !attachmentRecords.isEmpty {
                do {
                    try await cacheManager.upsertAttachments(attachmentRecords)
                } catch {
                    AppLogger.app.error("Cache upsertAttachments failed (conversation=\(conversationID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                }
            }
            if let thread {
                do {
                    try await cacheManager.upsertConversation(thread)
                } catch {
                    AppLogger.app.error("Cache upsertConversation failed (conversation=\(conversationID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func persistConversationSnapshotIfNeeded(_ conversationID: UUID) {
        guard let cacheManager = messageCacheManager,
              let thread = conversation(id: conversationID, for: sessionStore.currentRole) else { return }

        Task {
            do {
                try await cacheManager.upsertConversation(thread)
            } catch {
                AppLogger.app.error("Cache upsertConversation (snapshot) failed (conversation=\(conversationID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func sortedMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        messages.sorted(by: chatMessageSort)
    }

    func deduplicatedMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var seenMessageIDs: Set<UUID> = []
        var seenClientIDs: Set<UUID> = []
        var deduplicated: [ChatMessage] = []

        for message in sortedMessages(messages) {
            if seenMessageIDs.contains(message.id) {
                continue
            }
            if let clientID = message.clientID, seenClientIDs.contains(clientID) {
                continue
            }

            seenMessageIDs.insert(message.id)
            if let clientID = message.clientID {
                seenClientIDs.insert(clientID)
            }
            deduplicated.append(message)
        }

        return deduplicated
    }

    func unresolvedLocalMessages(
        from thread: ConversationThread,
        excluding records: [MessageRecord]
    ) -> [ChatMessage] {
        let serverIDs = Set(records.map(\.id))
        let serverClientIDs = Set(records.compactMap(\.clientID))

        return thread.messages.filter { message in
            guard message.status == .sending || message.status == .failed else { return false }
            guard !serverIDs.contains(message.id) else { return false }
            if let clientID = message.clientID {
                return !serverClientIDs.contains(clientID)
            }
            return true
        }
    }

    func mergeMessage(_ existing: ChatMessage, with incoming: ChatMessage) -> ChatMessage {
        ChatMessage(
            id: incoming.id,
            sender: incoming.sender,
            body: incoming.body,
            sentAt: incoming.sentAt,
            kind: incoming.kind,
            status: upgradedStatus(existing.status, incoming.status),
            clientID: incoming.clientID ?? existing.clientID,
            attachments: incoming.attachments.isEmpty ? existing.attachments : incoming.attachments,
            sequenceNumber: incoming.sequenceNumber ?? existing.sequenceNumber
        )
    }

    func upgradedStatus(_ current: MessageDeliveryStatus, _ incoming: MessageDeliveryStatus) -> MessageDeliveryStatus {
        let order: [MessageDeliveryStatus] = [.failed, .sending, .sent, .delivered, .read]
        let currentRank = order.firstIndex(of: current) ?? 0
        let incomingRank = order.firstIndex(of: incoming) ?? 0
        return incomingRank >= currentRank ? incoming : current
    }

    func chatMessageSort(_ lhs: ChatMessage, _ rhs: ChatMessage) -> Bool {
        switch (lhs.sequenceNumber, rhs.sequenceNumber) {
        case let (.some(left), .some(right)) where left != right:
            return left < right
        default:
            if lhs.sentAt != rhs.sentAt {
                return lhs.sentAt < rhs.sentAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func messageRecordSort(_ lhs: MessageRecord, _ rhs: MessageRecord) -> Bool {
        switch (lhs.sequenceNumber, rhs.sequenceNumber) {
        case let (.some(left), .some(right)) where left != right:
            return left < right
        default:
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
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

    func makeChatMessage(
        from record: MessageRecord,
        attachments: [MessageAttachment] = []
    ) -> ChatMessage {
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
            attachments: attachments,
            sequenceNumber: record.sequenceNumber
        )
    }
}
