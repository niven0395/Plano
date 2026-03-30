import Foundation
import Observation

@MainActor
@Observable
final class RequestsStore {
    enum Segment: String, CaseIterable, Identifiable {
        case pending
        case confirmed
        case saved

        var id: Self { self }

        var title: String {
            switch self {
            case .pending:
                "Pending"
            case .confirmed:
                "Confirmed"
            case .saved:
                "Saved"
            }
        }
    }

    enum Destination: Hashable {
        case conversation(UUID)
        case workspace(UUID)
    }

    struct RequestItem: Identifiable, Hashable {
        let id: UUID
        let vendorID: UUID
        let vendorName: String
        let vendorCategory: VendorCategory
        let detail: String
        let eventDateLabel: String
        let amountLabel: String
        let stage: BookingStage
        let primaryActionTitle: String
        let primaryDestination: Destination
        let paymentRequest: PaymentRequest?
        let isConfirmingPayment: Bool
    }

    struct CategoryGroup: Identifiable {
        let category: VendorCategory
        let vendors: [VendorItem]

        var id: VendorCategory { category }
    }

    struct VendorItem: Identifiable, Hashable {
        let id: UUID
        let vendorID: UUID
        let vendorName: String
        let category: VendorCategory
        let stage: BookingStage
        let priceLabel: String
        let eventDateLabel: String
        let conversationID: UUID
    }

    struct TeamSlot: Identifiable, Hashable {
        let category: VendorCategory
        let vendor: VendorProfile?
        let bookingStage: BookingStage?
        let conversationID: UUID?
        let priceLabel: String
        let primaryActionTitle: String

        var id: VendorCategory { category }

        var isConfirmed: Bool {
            bookingStage?.isConfirmed ?? false
        }
    }

let planner: HostPlanningStore
    let inboxStore: InboxStore

    init(planner: HostPlanningStore, inboxStore: InboxStore) {
        self.planner = planner
        self.inboxStore = inboxStore
    }

    var hasEvents: Bool {
        !planner.events.isEmpty
    }

    var events: [PartyEvent] {
        planner.events.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }

            return lhs.title < rhs.title
        }
    }

    var activeEvent: PartyEvent {
        planner.selectedEvent
    }

    var eventContextChips: [String] {
        guard hasEvents else { return [] }

        var chips = [
            activeEvent.formattedDate,
            activeEvent.city,
            activeEvent.guestCountLabel,
            activeEvent.venueSetting.title,
        ]
        if activeEvent.startTime != nil {
            chips.append(activeEvent.timeRangeLabel)
        }
        return chips
    }

    var daysUntilEvent: Int {
        guard hasEvents else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: .now, to: activeEvent.date).day ?? 0)
    }

    // MARK: - Category Groups (contacted vendors grouped by category)

    var categoryGroups: [CategoryGroup] {
        guard hasEvents else { return [] }
        return buildCategoryGroups(for: activeEvent)
    }

    // MARK: - Team Slots (per-category vendor status)

    var teamSlots: [TeamSlot] {
        guard hasEvents else { return [] }
        return buildTeamSlots(for: activeEvent)
    }

    var filledSlots: [TeamSlot] {
        teamSlots.filter { $0.vendor != nil }
    }

    var activeBookingCount: Int {
        categoryGroups.reduce(0) { $0 + $1.vendors.count }
    }

    func deleteActiveEvent() async -> DeletionResult? {
        await planner.deleteEvent(activeEvent.id)
    }

    // MARK: - Requests

    var pendingRequests: [RequestItem] {
        requestItems(from: eventThreads.filter(isPendingThread))
    }

    var confirmedRequests: [RequestItem] {
        requestItems(from: eventThreads.filter { $0.stage.isConfirmed })
    }

    // MARK: - Ungrouped Bookings

    var ungroupedConversations: [ConversationThread] {
        let existingEventIDs = Set(planner.events.map(\.id))
        return inboxStore.conversations
            .filter { $0.stage != .active }
            .filter { !$0.isHostCancelled && !inboxStore.isArchived($0.id, for: .host) }
            .filter { $0.eventID == nil || !existingEventIDs.contains($0.eventID!) }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    var hasUngroupedBookings: Bool {
        !ungroupedConversations.isEmpty
    }

    var ungroupedItems: [RequestItem] {
        requestItems(from: ungroupedConversations)
    }

    var shouldShowEventPrompt: Bool {
        ungroupedConversations.count >= 2 && !hasEvents
    }

    func linkToEvent(conversationID: UUID, eventID: UUID) async {
        try? await inboxStore.linkConversationToEvent(conversationID: conversationID, eventID: eventID)
    }

    func selectEvent(_ eventID: UUID) {
        planner.selectEvent(eventID)
    }

    // MARK: - Category Group Building

    private func buildCategoryGroups(for event: PartyEvent) -> [CategoryGroup] {
        let threads = inboxStore.eventConversations(eventID: event.id)
            .filter { !$0.isHostCancelled && !inboxStore.isArchived($0.id, for: .host) }

        let grouped = Dictionary(grouping: threads) { $0.vendorCategory }

        return grouped.keys
            .sorted { lhs, rhs in
                let order = VendorCategory.homeDisplayOrder
                let lhsIndex = order.firstIndex(of: lhs) ?? order.count
                let rhsIndex = order.firstIndex(of: rhs) ?? order.count
                return lhsIndex < rhsIndex
            }
            .compactMap { category -> CategoryGroup? in
                guard let categoryThreads = grouped[category], !categoryThreads.isEmpty else { return nil }

                let vendors = categoryThreads
                    .sorted(by: compareThreads)
                    .map { thread -> VendorItem in
                        let vendor = planner.vendor(id: thread.vendorID) ?? inboxStore.vendorProfile(id: thread.vendorID)
                        let priceLabel = thread.paymentRequest?.amountLabel ?? vendor?.planningPriceLabel ?? "Pricing on request"

                        return VendorItem(
                            id: thread.id,
                            vendorID: thread.vendorID,
                            vendorName: thread.vendorName,
                            category: thread.vendorCategory,
                            stage: thread.stage,
                            priceLabel: priceLabel,
                            eventDateLabel: thread.eventDateLabel,
                            conversationID: thread.id
                        )
                    }

                return CategoryGroup(category: category, vendors: vendors)
            }
    }

    // MARK: - Team Slot Building

    private func buildTeamSlots(for event: PartyEvent) -> [TeamSlot] {
        let threads = inboxStore.eventConversations(eventID: event.id)
        let categories = planner.categories(for: event)

        return categories.map { category in
            let plannedVendor = planner.plannedVendor(for: event.id, category: category)
            let thread = selectedThread(for: category, vendor: plannedVendor, within: threads)
            let vendor = plannedVendor ?? thread.flatMap {
                planner.vendor(id: $0.vendorID) ?? inboxStore.vendorProfile(id: $0.vendorID)
            }
            let priceLabel = thread?.paymentRequest?.amountLabel ?? vendor?.planningPriceLabel ?? "Pricing on request"

            return TeamSlot(
                category: category,
                vendor: vendor,
                bookingStage: thread?.stage,
                conversationID: thread?.id,
                priceLabel: priceLabel,
                primaryActionTitle: thread == nil ? (vendor?.primaryCTA ?? "Find vendor") : "Open chat"
            )
        }
    }

    private func selectedThread(
        for category: VendorCategory,
        vendor: VendorProfile?,
        within threads: [ConversationThread]
    ) -> ConversationThread? {
        let matchingThreads: [ConversationThread]

        if let vendor {
            matchingThreads = threads.filter { $0.vendorID == vendor.id }
        } else {
            matchingThreads = threads.filter { $0.vendorCategory == category }
        }

        return matchingThreads.sorted(by: compareThreads).first
    }

    private func compareThreads(lhs: ConversationThread, rhs: ConversationThread) -> Bool {
        if stageRank(lhs.stage) != stageRank(rhs.stage) {
            return stageRank(lhs.stage) > stageRank(rhs.stage)
        }

        return lhs.lastActivityAt > rhs.lastActivityAt
    }

    private func stageRank(_ stage: BookingStage) -> Int {
        switch stage {
        case .active:
            0
        case .requested:
            1
        case .cancellationRequested:
            2
        case .accepted:
            3
        case .paymentRequested:
            4
        case .paid:
            5
        case .declined, .cancelled:
            -1
        case .completed:
            6
        }
    }

    // MARK: - Request Items

    private var eventThreads: [ConversationThread] {
        guard hasEvents else { return [] }
        return inboxStore.eventConversations(eventID: activeEvent.id)
    }

    private func requestItems(from threads: [ConversationThread]) -> [RequestItem] {
        threads.map { thread in
            let summary = inboxStore.updatedSummary(from: requestSummary(for: thread), for: .host)

            return RequestItem(
                id: thread.id,
                vendorID: thread.vendorID,
                vendorName: summary.counterpartName,
                vendorCategory: thread.vendorCategory,
                detail: summary.detail,
                eventDateLabel: summary.eventDateLabel,
                amountLabel: summary.amountLabel,
                stage: summary.stage,
                primaryActionTitle: primaryActionTitle(for: summary.stage),
                primaryDestination: primaryDestination(for: thread),
                paymentRequest: thread.paymentRequest,
                isConfirmingPayment: inboxStore.confirmingPaymentIDs.contains(thread.id)
            )
        }
    }

    private func requestSummary(for thread: ConversationThread) -> BookingRequestSummary {
        BookingRequestSummary(
            id: thread.id,
            conversationID: thread.id,
            vendorID: thread.vendorID,
            eventID: thread.eventID,
            counterpartName: thread.vendorName,
            eventTitle: thread.contextTitle,
            eventDateLabel: thread.eventDateLabel,
            detail: thread.lastMessagePreview,
            amountLabel: thread.paymentRequest?.amountLabel ?? "Request in progress",
            stage: thread.stage
        )
    }

    private func primaryActionTitle(for stage: BookingStage) -> String {
        switch stage {
        case .accepted:
            "Review quote"
        case .paymentRequested:
            "Pay deposit"
        case .paid, .completed:
            "Open workspace"
        case .cancellationRequested:
            "View request"
        case .active, .requested, .declined, .cancelled:
            "Open chat"
        }
    }

    private func primaryDestination(for thread: ConversationThread) -> Destination {
        if thread.stage.isConfirmed, let eventID = thread.eventID {
            return .workspace(eventID)
        }

        return .conversation(thread.id)
    }

    private func isPendingThread(_ thread: ConversationThread) -> Bool {
        switch thread.stage {
        case .requested, .accepted, .paymentRequested, .cancellationRequested:
            true
        case .active, .paid, .declined, .cancelled, .completed:
            false
        }
    }

}
