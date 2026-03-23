import Foundation
import Observation

@MainActor
@Observable
final class EventPlanningStore {
    struct CategorySlot: Identifiable, Hashable {
        let category: VendorCategory
        var vendor: VendorProfile?
        var bookingStage: BookingStage?
        var conversationID: UUID?
        var isSuggested: Bool

        var id: VendorCategory { category }
    }

    let eventID: UUID
    let planner: HostPlanningStore
    let inboxStore: InboxStore
    let bookingService: any BookingServiceProtocol
    let availabilityService: any VendorAvailabilityServiceProtocol

    @ObservationIgnored private var hasLoaded = false

    var loadingState: LoadingState = .idle
    var categorySlots: [CategorySlot] = []

    init(
        eventID: UUID,
        planner: HostPlanningStore,
        inboxStore: InboxStore,
        bookingService: any BookingServiceProtocol,
        availabilityService: any VendorAvailabilityServiceProtocol
    ) {
        self.eventID = eventID
        self.planner = planner
        self.inboxStore = inboxStore
        self.bookingService = bookingService
        self.availabilityService = availabilityService
    }

    var event: PartyEvent? {
        planner.event(id: eventID)
    }

    var availableAdditionalCategories: [VendorCategory] {
        let occupied = Set(categorySlots.map(\.category))
        return VendorCategory.allCases.filter { !occupied.contains($0) }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        guard let event = planner.event(id: eventID) else {
            loadingState = .failed("This event is no longer available.")
            return
        }

        loadingState = .loading

        if eventID != planner.selectedEventID {
            planner.selectEvent(eventID)
        }

        let eventThreads = inboxStore.eventConversations(eventID: event.id)
        rebuildSlots(for: event, conversations: eventThreads)
        hasLoaded = true
        loadingState = .loaded
    }

    func addCategory(_ category: VendorCategory) {
        guard let event else { return }
        planner.addCategory(category, to: event)
        rebuildSlots(for: event, conversations: inboxStore.eventConversations(eventID: event.id))
    }

    private func rebuildSlots(for event: PartyEvent, conversations: [ConversationThread]) {
        let categories = planner.categories(for: event)

        categorySlots = categories.map { category in
            let thread = conversations
                .filter { $0.vendorCategory == category }
                .sorted(by: compareThreads)
                .first

            return CategorySlot(
                category: category,
                vendor: thread.flatMap { planner.vendor(id: $0.vendorID) ?? inboxStore.vendorProfile(id: $0.vendorID) },
                bookingStage: thread?.stage,
                conversationID: thread?.id,
                isSuggested: event.recommendedCategories.contains(category)
            )
        }
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
        case .accepted:
            3
        case .paymentRequested:
            4
        case .paid:
            5
        case .cancellationRequested:
            2
        case .declined, .cancelled:
            -1
        case .completed:
            6
        }
    }
}
