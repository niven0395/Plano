import Foundation
import OSLog

// MARK: - Query helpers, archive/draft/assistant delegates, vendor profile accessors

extension InboxStore {

    func visibleConversations(for role: UserRole) -> [ConversationSummary] {
        scopedConversations(for: role)
            .filter { matchesCurrentFilter($0, role: role) }
            .map { $0.summary(for: role, formatter: relativeFormatter) }
    }

    func unreadCount(for role: UserRole) -> Int {
        scopedConversations(for: role)
            .filter { !isArchived($0.id, for: role) }
            .reduce(0) { $0 + $1.unreadCount(for: role) }
    }

    func conversation(id: UUID, for role: UserRole) -> ConversationThread? {
        scopedConversations(for: role).first(where: { $0.id == id })
    }

    func ensureConversationLoaded(_ conversationID: UUID, for role: UserRole) async -> ConversationThread? {
        if let existing = conversation(id: conversationID, for: role) {
            return existing
        }

        await loadConversations(for: role)
        return conversation(id: conversationID, for: role)
    }

    func latestConversationID(for role: UserRole) -> UUID? {
        scopedConversations(for: role)
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
            .first?.id
    }

    func vendorScopedConversations() -> [ConversationThread] {
        guard sessionStore.isVendorAuthenticated, sessionStore.currentRole == .vendor else { return [] }
        return scopedConversations(for: .vendor)
    }

    var activeVendorBookingCount: Int {
        vendorScopedConversations()
            .filter { $0.stage.isActionable }
            .count
    }

    var activeHostBookingCount: Int {
        scopedConversations(for: .host)
            .filter { $0.stage.isActionable }
            .count
    }

    func reload() async {
        await loadConversations(for: sessionStore.currentRole)
    }

    func setActiveConversation(_ conversationID: UUID?, for role: UserRole) {
        activeConversationID = conversationID
        activeConversationRole = conversationID == nil ? nil : role
    }

    func isActiveConversation(_ conversationID: UUID, for role: UserRole) -> Bool {
        activeConversationID == conversationID && activeConversationRole == role
    }

    func loadCachedConversations(for role: UserRole, userID: UUID) async {
        guard conversations.isEmpty,
              let cacheManager = messageCacheManager else { return }

        do {
            let cachedRecords = try await cacheManager.fetchCachedConversations()
            let filteredRecords = cachedRecords.filter { record in
                switch role {
                case .host:
                    record.hostUserID == userID
                case .vendor:
                    record.vendorID == userID
                }
            }

            guard !filteredRecords.isEmpty else { return }

            conversations = filteredRecords.map { record in
                ConversationThread(
                    id: record.id,
                    eventID: record.eventID,
                    vendorID: record.vendorID,
                    hostUserID: record.hostUserID,
                    hostName: record.hostName,
                    vendorName: record.vendorName,
                    vendorCategory: VendorCategory.fromDatabaseValue(record.vendorCategory) ?? .entertainer,
                    eventTitle: record.eventTitle,
                    eventDateLabel: record.eventDateLabel,
                    eventContextLine: record.eventContextLine,
                    stage: BookingStage.fromDatabaseValue(record.stage),
                    messages: [],
                    lastActivityAt: record.lastActivityAt,
                    lastMessagePreviewText: record.lastMessagePreviewText,
                    hostUnreadCount: record.hostUnreadCount,
                    vendorUnreadCount: record.vendorUnreadCount
                )
            }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
        } catch {
            AppLogger.networking.error("Failed to load cached conversations: \(error.localizedDescription, privacy: .public)")
        }
    }

    func existingConversationID(vendorID: UUID) -> UUID? {
        guard let hostUserID = sessionStore.currentUserID else { return nil }

        return conversations.first { thread in
            thread.hostUserID == hostUserID &&
            thread.vendorID == vendorID
        }?.id
    }

    // MARK: - Archive (delegates to InboxArchiveManager)

    func archiveConversation(_ conversationID: UUID, for role: UserRole) {
        archiveManager.archive(conversationID, for: role)
    }

    func unarchiveConversation(_ conversationID: UUID, for role: UserRole) {
        archiveManager.unarchive(conversationID, for: role)
    }

    func isArchived(_ conversationID: UUID, for role: UserRole) -> Bool {
        archiveManager.isArchived(conversationID, for: role)
    }

    // MARK: - Vendor profiles & conflicts

    func vendorProfile(id: UUID) -> VendorProfile? {
        vendorProfilesByID[id]
    }

    func refreshVendorProfile(id vendorID: UUID) {
        vendorProfilesByID.removeValue(forKey: vendorID)
    }

    func dateConflicts(in conversationID: UUID) -> [DateConflict] {
        dateConflictsByConversation[conversationID] ?? []
    }

    func bookingRequest(for conversationID: UUID) -> BookingRequestRecord? {
        bookingRequestsByConversation[conversationID]
    }

    // MARK: - Drafts (delegates to InboxDraftManager)

    func draft(for conversationID: UUID, role: UserRole) -> String {
        draftManager.draft(for: conversationID, role: role)
    }

    func updateDraft(_ text: String, for conversationID: UUID, role: UserRole) {
        draftManager.updateDraft(text, for: conversationID, role: role)
    }

    // MARK: - Assistant brief (delegates to ConversationAssistantService)

    func updatedSummary(from summary: BookingRequestSummary, for role: UserRole) -> BookingRequestSummary {
        guard let conversationID = summary.conversationID,
              let thread = conversation(id: conversationID, for: role) else {
            return summary
        }

        return ConversationAssistantService.updatedSummary(from: summary, thread: thread, role: role)
    }

    func assistantBrief(for conversationID: UUID, role: UserRole) -> ConversationAssistantBrief? {
        guard let thread = conversation(id: conversationID, for: role) else { return nil }
        return ConversationAssistantService.assistantBrief(for: thread, role: role)
    }

    func loadSuggestedReply(_ reply: String, for conversationID: UUID, role: UserRole) {
        updateDraft(reply, for: conversationID, role: role)
    }

    // MARK: - Host identity sync

    func syncHostIdentityFromSession() {
        guard let hostUserID = sessionStore.currentUserID else { return }

        conversations = conversations.map { thread in
            guard thread.hostUserID == hostUserID else { return thread }

            return ConversationThread(
                id: thread.id,
                eventID: thread.eventID,
                eventDate: thread.eventDate,
                vendorID: thread.vendorID,
                hostUserID: thread.hostUserID,
                hostName: sessionStore.hostName,
                vendorName: thread.vendorName,
                vendorCategory: thread.vendorCategory,
                eventTitle: thread.eventTitle,
                eventDateLabel: thread.eventDateLabel,
                eventContextLine: thread.eventContextLine,
                stage: thread.stage,
                bookingEventDate: thread.bookingEventDate,
                paymentRequest: thread.paymentRequest,
                messages: thread.messages,
                lastActivityAt: thread.lastActivityAt,
                lastMessagePreviewText: thread.lastMessagePreviewText,
                hostUnreadCount: thread.hostUnreadCount,
                vendorUnreadCount: thread.vendorUnreadCount,
                hasLoadedInitialMessages: thread.hasLoadedInitialMessages,
                hasOlderMessages: thread.hasOlderMessages,
                isLoadingMessages: thread.isLoadingMessages,
                cancellationRequestDeadline: thread.cancellationRequestDeadline,
                cancellationRequestedByRole: thread.cancellationRequestedByRole,
                cancellationDeclinedAt: thread.cancellationDeclinedAt,
                venueSettingLabel: thread.venueSettingLabel,
                timeRangeLabel: thread.timeRangeLabel
            )
        }
    }

    func syncVendorIdentityFromSession() {
        guard let vendorID = sessionStore.currentUserID else { return }

        conversations = conversations.map { thread in
            guard thread.vendorID == vendorID else { return thread }

            return ConversationThread(
                id: thread.id,
                eventID: thread.eventID,
                eventDate: thread.eventDate,
                vendorID: thread.vendorID,
                hostUserID: thread.hostUserID,
                hostName: thread.hostName,
                vendorName: sessionStore.vendorName,
                vendorCategory: thread.vendorCategory,
                eventTitle: thread.eventTitle,
                eventDateLabel: thread.eventDateLabel,
                eventContextLine: thread.eventContextLine,
                stage: thread.stage,
                bookingEventDate: thread.bookingEventDate,
                paymentRequest: thread.paymentRequest,
                messages: thread.messages,
                lastActivityAt: thread.lastActivityAt,
                lastMessagePreviewText: thread.lastMessagePreviewText,
                hostUnreadCount: thread.hostUnreadCount,
                vendorUnreadCount: thread.vendorUnreadCount,
                hasLoadedInitialMessages: thread.hasLoadedInitialMessages,
                hasOlderMessages: thread.hasOlderMessages,
                isLoadingMessages: thread.isLoadingMessages,
                cancellationRequestDeadline: thread.cancellationRequestDeadline,
                cancellationRequestedByRole: thread.cancellationRequestedByRole,
                cancellationDeclinedAt: thread.cancellationDeclinedAt,
                venueSettingLabel: thread.venueSettingLabel,
                timeRangeLabel: thread.timeRangeLabel
            )
        }
    }
}
