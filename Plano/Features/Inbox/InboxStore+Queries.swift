import Foundation

// MARK: - Query helpers, archive/draft/assistant delegates, vendor profile accessors

extension InboxStore {

    func visibleConversations(for role: UserRole) -> [ConversationSummary] {
        scopedConversations(for: role)
            .filter { matchesCurrentFilter($0, role: role) }
            .map { $0.summary(for: role, formatter: relativeFormatter) }
    }

    func unreadCount(for role: UserRole) -> Int {
        scopedConversations(for: role)
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

    func eventConversations(eventID: UUID) -> [ConversationThread] {
        conversations
            .filter { $0.eventID == eventID }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    func ungroupedBookingConversations() -> [ConversationThread] {
        conversations
            .filter { $0.eventID == nil && $0.stage != .active }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    func linkConversationToEvent(conversationID: UUID, eventID: UUID) async throws {
        try await bookingService.linkConversationToEvent(conversationID: conversationID, eventID: eventID)
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].eventID = eventID
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

    func existingConversationID(vendorID: UUID, eventID: UUID?) -> UUID? {
        guard let hostUserID = sessionStore.currentUserID else { return nil }

        return conversations.first { thread in
            thread.hostUserID == hostUserID &&
            thread.vendorID == vendorID &&
            thread.eventID == eventID
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
                hostUnreadCount: thread.hostUnreadCount,
                vendorUnreadCount: thread.vendorUnreadCount
            )
        }
    }
}
