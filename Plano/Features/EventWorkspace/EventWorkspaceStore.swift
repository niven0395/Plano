import Foundation
import Observation

struct EventWorkspaceReminder: Identifiable, Hashable {
    let id: UUID
    let title: String
    let detail: String
    let symbolName: String
    let tone: AccentTone
    let conversationID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        symbolName: String,
        tone: AccentTone,
        conversationID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.tone = tone
        self.conversationID = conversationID
    }
}

struct EventWorkspacePartner: Identifiable, Hashable {
    let id: UUID
    let conversationID: UUID
    let title: String
    let subtitle: String
    let stage: BookingStage
    let paymentLabel: String
    let balanceLabel: String
    let nextStep: String
    let note: String
}

struct HostEventWorkspaceSnapshot: Identifiable, Hashable {
    let id: UUID
    let event: PartyEvent
    let countdownLabel: String
    let metrics: [MetricSummary]
    let reminders: [EventWorkspaceReminder]
    let confirmedPartners: [EventWorkspacePartner]
    let activePartners: [EventWorkspacePartner]
    let isLiveActivityActive: Bool
    let usesPreviewLiveActivity: Bool
}

struct VendorEventWorkspaceSnapshot: Identifiable, Hashable {
    let id: UUID
    let title: String
    let hostName: String
    let serviceLine: String
    let dateLabel: String
    let venue: String
    let guestCountLabel: String
    let countdownLabel: String
    let stage: BookingStage
    let paymentLabel: String
    let balanceLabel: String
    let metrics: [MetricSummary]
    let reminders: [EventWorkspaceReminder]
    let conversationID: UUID?
    let note: String
    let isLiveActivityActive: Bool
    let usesPreviewLiveActivity: Bool
    let coBookedVendors: [CoBookedVendor]
}

@MainActor
@Observable
final class EventWorkspaceStore {
    let planner: HostPlanningStore
    let inboxStore: InboxStore
    let vendorDashboardStore: VendorDashboardStore
    private let bookingService: any BookingServiceProtocol

    private let calendar: Calendar
    @ObservationIgnored private let currencyFormatter: NumberFormatter
    @ObservationIgnored private let liveActivityCoordinator = EventLiveActivityCoordinator()

    var activeLiveActivityEventIDs: Set<UUID> = []
    var previewLiveActivityEventIDs: Set<UUID> = []
    private var coVendorCache: [UUID: [CoBookedVendor]] = [:]

    init(
        planner: HostPlanningStore,
        inboxStore: InboxStore,
        vendorDashboardStore: VendorDashboardStore,
        bookingService: any BookingServiceProtocol,
        calendar: Calendar = .current
    ) {
        self.planner = planner
        self.inboxStore = inboxStore
        self.vendorDashboardStore = vendorDashboardStore
        self.bookingService = bookingService
        self.calendar = calendar

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.locale = .current
        currencyFormatter = formatter
    }

    func hostWorkspace(for eventID: UUID) -> HostEventWorkspaceSnapshot? {
        guard let event = planner.events.first(where: { $0.id == eventID }) else { return nil }

        let threads = inboxStore.eventConversations(eventID: eventID)
        let confirmedThreads = threads.filter { $0.stage == .paid }
        let activeThreads = threads.filter { $0.stage != .paid }

        let paidTotal = confirmedThreads
            .compactMap { currencyValue(from: $0.paymentRequest?.amountLabel) }
            .reduce(0, +)
        let remainingTotal = confirmedThreads
            .compactMap(remainingBalanceValue(for:))
            .reduce(0, +)

        return HostEventWorkspaceSnapshot(
            id: event.id,
            event: event,
            countdownLabel: countdownLabel(for: event.date),
            metrics: [
                MetricSummary(
                    title: "Booked",
                    value: "\(confirmedThreads.count)",
                    detail: "confirmed vendors",
                    tone: .sage
                ),
                MetricSummary(
                    title: "Paid",
                    value: currencyLabel(for: paidTotal),
                    detail: "deposit total",
                    tone: .blue
                ),
                MetricSummary(
                    title: "Balance",
                    value: currencyLabel(for: remainingTotal),
                    detail: "remaining vendor balance",
                    tone: .gold
                ),
                MetricSummary(
                    title: "Open",
                    value: "\(activeThreads.count)",
                    detail: "threads still in flight",
                    tone: activeThreads.isEmpty ? .sage : .coral
                ),
            ],
            reminders: hostReminders(event: event, confirmedThreads: confirmedThreads, activeThreads: activeThreads),
            confirmedPartners: confirmedThreads.map { hostPartner(from: $0, event: event) },
            activePartners: activeThreads.map { hostPartner(from: $0, event: event) },
            isLiveActivityActive: activeLiveActivityEventIDs.contains(event.id),
            usesPreviewLiveActivity: previewLiveActivityEventIDs.contains(event.id)
        )
    }

    var vendorWorkspaces: [VendorEventWorkspaceSnapshot] {
        let confirmedThreads = inboxStore.vendorScopedConversations()
            .filter { $0.stage == .paid }
            .map { thread in
                let coVendors = coVendorCache[thread.eventID ?? thread.id] ?? []
                return vendorWorkspace(from: thread, coVendors: coVendors)
            }

        let fallbackEvents = vendorDashboardStore.upcomingEvents
            .filter { $0.stage == .paid }
            .map(vendorWorkspace(from:))

        var seenKeys = Set<String>()
        let merged = (confirmedThreads + fallbackEvents).filter { workspace in
            seenKeys.insert(workspaceKey(title: workspace.title, dateLabel: workspace.dateLabel)).inserted
        }

        return merged.sorted(by: compareVendorWorkspaces)
    }

    func invalidateCoVendorCache(eventID: UUID) {
        coVendorCache.removeValue(forKey: eventID)
    }

    func invalidateAllCoVendorCaches() {
        coVendorCache.removeAll()
    }

    func loadCoVendors(eventID: UUID, vendorID: UUID, forceRefresh: Bool = false) async {
        guard forceRefresh || coVendorCache[eventID] == nil else { return }

        do {
            let records = try await bookingService.fetchEventConfirmedVendors(
                eventID: eventID,
                requestingVendorID: vendorID
            )
            coVendorCache[eventID] = records.map { $0.toDomain() }
        } catch {
            coVendorCache[eventID] = []
        }
    }

    func coVendorCount(for eventID: UUID?) -> Int {
        guard let eventID else { return 0 }
        return coVendorCache[eventID]?.count ?? 0
    }

    func vendorWorkspace(for workspaceID: UUID) -> VendorEventWorkspaceSnapshot? {
        vendorWorkspaces.first(where: { $0.id == workspaceID })
    }

    func toggleLiveActivity(
        eventID: UUID,
        title: String,
        venue: String,
        countdownLabel: String,
        detail: String
    ) async {
        if activeLiveActivityEventIDs.contains(eventID) {
            activeLiveActivityEventIDs.remove(eventID)
            previewLiveActivityEventIDs.remove(eventID)
            await liveActivityCoordinator.stopTracking(eventID: eventID)
            return
        }

        let mode = await liveActivityCoordinator.startTracking(
            eventID: eventID,
            title: title,
            venue: venue,
            countdownLabel: countdownLabel,
            detail: detail
        )

        activeLiveActivityEventIDs.insert(eventID)

        switch mode {
        case .system:
            previewLiveActivityEventIDs.remove(eventID)
        case .preview:
            previewLiveActivityEventIDs.insert(eventID)
        }
    }

    private func hostPartner(from thread: ConversationThread, event: PartyEvent) -> EventWorkspacePartner {
        EventWorkspacePartner(
            id: thread.id,
            conversationID: thread.id,
            title: thread.vendorName,
            subtitle: thread.vendorCategory.singularTitle,
            stage: thread.stage,
            paymentLabel: paymentLabel(for: thread),
            balanceLabel: balanceLabel(for: thread),
            nextStep: hostNextStep(for: thread, eventDate: event.date),
            note: thread.paymentRequest?.note ?? thread.lastMessagePreview
        )
    }

    private func vendorWorkspace(from thread: ConversationThread, coVendors: [CoBookedVendor] = []) -> VendorEventWorkspaceSnapshot {
        let eventDate = parsedDate(from: thread.eventDateLabel)
        let reminders = vendorReminders(for: thread, eventDate: eventDate)
        let workspaceID = thread.eventID ?? thread.id

        return VendorEventWorkspaceSnapshot(
            id: workspaceID,
            title: thread.eventTitle,
            hostName: thread.hostName,
            serviceLine: thread.vendorCategory.singularTitle,
            dateLabel: thread.eventDateLabel,
            venue: venue(from: thread.eventContextLine),
            guestCountLabel: thread.guestCountLabel,
            countdownLabel: eventDate.map(countdownLabel(for:)) ?? "Upcoming event",
            stage: thread.stage,
            paymentLabel: paymentLabel(for: thread),
            balanceLabel: balanceLabel(for: thread),
            metrics: vendorMetrics(for: thread, reminders: reminders),
            reminders: reminders,
            conversationID: thread.id,
            note: thread.paymentRequest?.note ?? thread.lastMessagePreview,
            isLiveActivityActive: activeLiveActivityEventIDs.contains(workspaceID),
            usesPreviewLiveActivity: previewLiveActivityEventIDs.contains(workspaceID),
            coBookedVendors: coVendors
        )
    }

    private func vendorWorkspace(from summary: EventSummary) -> VendorEventWorkspaceSnapshot {
        let reminders = [
            EventWorkspaceReminder(
                title: "Hold the arrival window",
                detail: summary.completionText,
                symbolName: "clock.badge.checkmark",
                tone: summary.stage == .paid ? .sage : .gold
            ),
            EventWorkspaceReminder(
                title: "Keep notes in thread",
                detail: "Use the inbox workspace for final room details and timing changes.",
                symbolName: "bubble.left.and.bubble.right",
                tone: .blue
            ),
        ]

        return VendorEventWorkspaceSnapshot(
            id: summary.id,
            title: summary.title,
            hostName: "Host coordination active",
            serviceLine: summary.kind,
            dateLabel: summary.dateLabel,
            venue: summary.venue,
            guestCountLabel: summary.guestCountLabel,
            countdownLabel: parsedDate(from: summary.dateLabel).map(countdownLabel(for:)) ?? "Upcoming event",
            stage: summary.stage,
            paymentLabel: summary.stage == .paid ? "Deposit received" : summary.completionText,
            balanceLabel: "Coordination in progress",
            metrics: [
                MetricSummary(title: "Status", value: summary.stage.title, detail: "workspace readiness", tone: summary.stage.tone),
                MetricSummary(title: "Progress", value: "\(Int(summary.progress * 100))%", detail: "prep completion", tone: .blue),
                MetricSummary(title: "Notes", value: "\(reminders.count)", detail: "live reminders", tone: .gold),
            ],
            reminders: reminders,
            conversationID: nil,
            note: summary.completionText,
            isLiveActivityActive: activeLiveActivityEventIDs.contains(summary.id),
            usesPreviewLiveActivity: previewLiveActivityEventIDs.contains(summary.id),
            coBookedVendors: []
        )
    }

    private func vendorMetrics(
        for thread: ConversationThread,
        reminders: [EventWorkspaceReminder]
    ) -> [MetricSummary] {
        [
            MetricSummary(
                title: "Deposit",
                value: depositMetricValue(for: thread),
                detail: depositMetricDetail(for: thread),
                tone: thread.paymentRequest?.status == .paid ? .sage : .gold
            ),
            MetricSummary(
                title: "Balance",
                value: balanceMetricValue(for: thread),
                detail: "remaining balance",
                tone: .blue
            ),
            MetricSummary(
                title: "Unread",
                value: "\(thread.vendorUnreadCount)",
                detail: "messages to review",
                tone: thread.vendorUnreadCount == 0 ? .sage : .coral
            ),
            MetricSummary(
                title: "Next",
                value: "\(reminders.count)",
                detail: "coordination reminders",
                tone: .sand
            ),
        ]
    }

    private func hostReminders(
        event: PartyEvent,
        confirmedThreads: [ConversationThread],
        activeThreads: [ConversationThread]
    ) -> [EventWorkspaceReminder] {
        var reminders: [EventWorkspaceReminder] = activeThreads.compactMap { thread in
            switch thread.stage {
            case .active:
                EventWorkspaceReminder(
                    title: "Finish the first request for \(thread.vendorName)",
                    detail: "The thread is open, but the structured request still needs to be sent.",
                    symbolName: "square.and.pencil",
                    tone: .sand,
                    conversationID: thread.id
                )
            case .requested:
                EventWorkspaceReminder(
                    title: "\(thread.vendorName) has the full request",
                    detail: "The structured request is live. Keep follow-up notes tight while the vendor reviews it.",
                    symbolName: "square.and.pencil",
                    tone: .sand,
                    conversationID: thread.id
                )
            case .accepted:
                EventWorkspaceReminder(
                    title: "Review \(thread.vendorName)'s quote",
                    detail: "A live quote is waiting in the conversation.",
                    symbolName: "doc.text.magnifyingglass",
                    tone: .blue,
                    conversationID: thread.id
                )
            case .paymentRequested:
                paymentReminder(for: thread)
            case .paid:
                nil
            case .cancellationRequested:
                EventWorkspaceReminder(
                    title: "Cancellation requested for \(thread.vendorName)",
                    detail: "The host has requested to cancel. Review the request in the conversation.",
                    symbolName: "exclamationmark.triangle",
                    tone: .gold,
                    conversationID: thread.id
                )
            case .declined, .cancelled, .completed:
                nil
            }
        }

        reminders.append(
            contentsOf: confirmedThreads.map {
                coordinationReminder(for: $0, eventDate: event.date, role: .host)
            }
        )

        if confirmedThreads.isEmpty {
            reminders.append(
                EventWorkspaceReminder(
                    title: "Lock the first confirmed vendor",
                    detail: "Confirm your first vendor so event coordination has a real anchor.",
                    symbolName: "checkmark.seal",
                    tone: .sand
                )
            )
        }

        return Array(reminders.prefix(5))
    }

    private func vendorReminders(
        for thread: ConversationThread,
        eventDate: Date?
    ) -> [EventWorkspaceReminder] {
        var reminders = [
            coordinationReminder(for: thread, eventDate: eventDate, role: .vendor),
        ]

        if let payment = thread.paymentRequest, payment.status == .paid {
            reminders.append(
                EventWorkspaceReminder(
                    title: "Payment captured",
                    detail: "\(payment.amountLabel) received.",
                    symbolName: "checkmark.circle",
                    tone: .sage,
                    conversationID: thread.id
                )
            )
        }

        reminders.append(
            EventWorkspaceReminder(
                title: "Keep host notes in-thread",
                detail: "The latest conversation update stays attached to this event workspace automatically.",
                symbolName: "bubble.left.and.bubble.right",
                tone: .blue,
                conversationID: thread.id
            )
        )

        return Array(reminders.prefix(4))
    }

    private func coordinationReminder(
        for thread: ConversationThread,
        eventDate: Date?,
        role: UserRole
    ) -> EventWorkspaceReminder {
        let daysLabel = eventDate.map(countdownLabel(for:)) ?? "Upcoming event"
        let title: String
        let detail: String
        let symbolName: String

        switch (role, thread.vendorCategory) {
        case (.host, .decorator):
            title = "Approve the install window"
            detail = "\(thread.vendorName) should get final palette notes and arrival access before \(daysLabel.lowercased())."
            symbolName = "paintpalette"
        case (.host, .photographer):
            title = "Lock the shot list"
            detail = "Use the thread to confirm portraits, cocktail-hour flow, and any VIP coverage before \(daysLabel.lowercased())."
            symbolName = "camera.aperture"
        case (.host, .dj):
            title = "Confirm music pacing"
            detail = "Share arrival, dinner, and close timing so the room program stays calm and controlled."
            symbolName = "music.note"
        case (.host, .caterer):
            title = "Finalize guest count and menu notes"
            detail = "Push the final dietary count and tasting decisions to \(thread.vendorName) before event week."
            symbolName = "fork.knife.circle"
        case (.host, .eventSpace):
            title = "Reconfirm venue access"
            detail = "Keep layout changes and vendor load-in timing inside the workspace to avoid drift."
            symbolName = "building.2.crop.circle"
        case (.vendor, .decorator):
            title = "Confirm load-in and palette"
            detail = "Lock the host's final install window and focal-point notes while the thread is still fresh."
            symbolName = "paintbrush.pointed"
        case (.vendor, .photographer):
            title = "Refine coverage timing"
            detail = "Reconfirm portrait timing, shot priorities, and gallery expectations before the event countdown tightens."
            symbolName = "camera.metering.center.weighted"
        case (.vendor, .dj):
            title = "Recheck room pacing"
            detail = "Keep arrival cues, dinner transitions, and the close sequence aligned with the host's notes."
            symbolName = "speaker.wave.3"
        case (.vendor, .caterer):
            title = "Hold staffing and menu locks"
            detail = "Use the thread for final guest count changes so staffing and service tempo stay correct."
            symbolName = "takeoutbag.and.cup.and.straw"
        case (.vendor, .eventSpace):
            title = "Reconfirm room flow"
            detail = "Keep floor plan adjustments and access notes centralized here for the event day team."
            symbolName = "rectangle.grid.2x2"
        case (.host, _):
            title = "Keep final details in one thread"
            detail = "Use the vendor thread to confirm timing, scope, and any event-week changes before \(daysLabel.lowercased())."
            symbolName = "checklist"
        case (.vendor, _):
            title = "Lock the event brief"
            detail = "Keep the host's latest scope, timing, and day-of notes centralized so nothing drifts before service."
            symbolName = "checklist"
        }

        return EventWorkspaceReminder(
            title: title,
            detail: detail,
            symbolName: symbolName,
            tone: .blue,
            conversationID: thread.id
        )
    }

    private func hostNextStep(for thread: ConversationThread, eventDate: Date) -> String {
        switch thread.stage {
        case .active:
            "Package the scope into a structured request so the vendor can review real details."
        case .requested:
            "The structured request is already in the vendor queue. Use chat only for important clarifications."
        case .accepted:
            "Review the quote and approve or revise it before the expiry window closes."
        case .paymentRequested:
            paymentInstruction(for: thread, eventDate: eventDate)
        case .paid:
            coordinationReminder(for: thread, eventDate: eventDate, role: .host).title
        case .cancellationRequested:
            "A cancellation request is pending vendor approval."
        case .declined:
            "Decide whether to reopen scope here or move on to another vendor."
        case .cancelled:
            "Keep any closeout details in thread and reset this category in planning."
        case .completed:
            "Use the thread for any final recap, delivery, or archival details."
        }
    }

    private func paymentLabel(for thread: ConversationThread) -> String {
        switch thread.stage {
        case .active, .requested:
            thread.paymentRequest?.amountLabel ?? "Estimate pending"
        case .accepted:
            thread.paymentRequest?.amountLabel ?? "Quote ready"
        case .paymentRequested:
            switch vendorProfile(for: thread)?.paymentMode ?? .platform {
            case .platform:
                if let amountLabel = thread.paymentRequest?.amountLabel {
                    "\(amountLabel) on Plano"
                } else {
                    "Pay on Plano"
                }
            case .cashOnly:
                if let amountLabel = thread.paymentRequest?.amountLabel {
                    "\(amountLabel) cash"
                } else {
                    "Cash payment due"
                }
            case .external:
                if let amountLabel = thread.paymentRequest?.amountLabel {
                    "\(amountLabel) direct"
                } else {
                    "Direct payment due"
                }
            }
        case .paid:
            thread.paymentRequest?.amountLabel ?? "Confirmed"
        case .cancellationRequested:
            "Cancellation pending"
        case .declined:
            "Declined"
        case .cancelled:
            "Cancelled"
        case .completed:
            thread.paymentRequest?.amountLabel ?? "Completed"
        }
    }

    private func balanceLabel(for thread: ConversationThread) -> String {
        if let remaining = remainingBalanceValue(for: thread) {
            return "\(currencyLabel(for: remaining)) remaining"
        }

        if let amountLabel = thread.paymentRequest?.amountLabel {
            return amountLabel
        }

        return thread.stage.title
    }

    private func depositMetricValue(for thread: ConversationThread) -> String {
        thread.paymentRequest?.amountLabel ?? "Pending"
    }

    private func depositMetricDetail(for thread: ConversationThread) -> String {
        if thread.paymentRequest?.status == .paid {
            return "payment received"
        }

        return thread.stage == .paid ? "booking locked" : "due to confirm"
    }

    private func paymentReminder(for thread: ConversationThread) -> EventWorkspaceReminder {
        let paymentMode = vendorProfile(for: thread)?.paymentMode ?? .platform

        switch paymentMode {
        case .platform:
            return EventWorkspaceReminder(
                title: "Pay \(thread.vendorName)'s deposit",
                detail: thread.paymentRequest?.amountLabel ?? "Deposit payment is required to lock this booking.",
                symbolName: "applepay",
                tone: .coral,
                conversationID: thread.id
            )
        case .cashOnly:
            return EventWorkspaceReminder(
                title: "Prepare \(thread.vendorName)'s cash deposit",
                detail: thread.paymentRequest?.amountLabel ?? "Cash payment is required directly with the vendor before the booking locks.",
                symbolName: "banknote.fill",
                tone: .gold,
                conversationID: thread.id
            )
        case .external:
            return EventWorkspaceReminder(
                title: "Coordinate \(thread.vendorName)'s direct payment",
                detail: thread.paymentRequest?.amountLabel ?? "Payment is handled outside Plano and should be recorded once arranged.",
                symbolName: "arrow.left.arrow.right.circle.fill",
                tone: .gold,
                conversationID: thread.id
            )
        }
    }

    private func paymentInstruction(for thread: ConversationThread, eventDate: Date) -> String {
        let countdown = countdownLabel(for: eventDate).lowercased()

        switch vendorProfile(for: thread)?.paymentMode ?? .platform {
        case .platform:
            return "Pay the deposit on Plano to confirm the booking before \(countdown)."
        case .cashOnly:
            return "Prepare the cash deposit directly with the vendor before \(countdown), then record it here so the event stays accurate."
        case .external:
            return "Coordinate the direct payment with the vendor before \(countdown), then record it here so the event stays accurate."
        }
    }

    private func balanceMetricValue(for thread: ConversationThread) -> String {
        if let remaining = remainingBalanceValue(for: thread) {
            return currencyLabel(for: remaining)
        }

        return thread.paymentRequest?.amountLabel ?? "TBD"
    }

    private func remainingBalanceValue(for thread: ConversationThread) -> Double? {
        guard let amountLabel = thread.paymentRequest?.amountLabel,
              let total = currencyValue(from: amountLabel) else { return nil }
        return max(total, 0)
    }

    private func venue(from contextLine: String) -> String {
        contextLine
            .split(separator: "•")
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? contextLine
    }

    private func vendorProfile(for thread: ConversationThread) -> VendorProfile? {
        planner.vendor(id: thread.vendorID) ?? inboxStore.vendorProfile(id: thread.vendorID)
    }

    private func currencyValue(from label: String?) -> Double? {
        guard let label else { return nil }

        let digits = label.filter { $0.isNumber || $0 == "." }
        guard !digits.isEmpty else { return nil }
        return Double(digits)
    }

    private func currencyLabel(for amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func countdownLabel(for date: Date) -> String {
        let startOfToday = calendar.startOfDay(for: .now)
        let startOfEvent = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfEvent).day ?? 0

        return switch days {
        case ..<0:
            "Event passed"
        case 0:
            "Today"
        case 1:
            "Tomorrow"
        default:
            "\(days) days out"
        }
    }

    private func parsedDate(from label: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEEE, MMMM d"

        guard let partialDate = formatter.date(from: label) else { return nil }

        var components = calendar.dateComponents([.month, .day], from: partialDate)
        components.year = calendar.component(.year, from: .now)
        return calendar.date(from: components)
    }

    private func compareVendorWorkspaces(
        lhs: VendorEventWorkspaceSnapshot,
        rhs: VendorEventWorkspaceSnapshot
    ) -> Bool {
        let lhsDate = parsedDate(from: lhs.dateLabel) ?? .distantFuture
        let rhsDate = parsedDate(from: rhs.dateLabel) ?? .distantFuture

        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }

        return lhs.title < rhs.title
    }

    private func workspaceKey(title: String, dateLabel: String) -> String {
        "\(title.lowercased())|\(dateLabel.lowercased())"
    }
}
