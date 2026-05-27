import Foundation
import Observation
import OSLog

enum RevenueTimeRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "7D"
    case month = "30D"
    case year = "1Y"
    case allTime = "All"

    var id: Self { self }

    var cutoffDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .today: return calendar.startOfDay(for: .now)
        case .week: return calendar.date(byAdding: .day, value: -7, to: .now)
        case .month: return calendar.date(byAdding: .day, value: -30, to: .now)
        case .year: return calendar.date(byAdding: .year, value: -1, to: .now)
        case .allTime: return nil
        }
    }
}

struct RevenueLineItem: Identifiable, Hashable {
    let id: UUID
    let conversationID: UUID
    let hostName: String
    let bookingDateLabel: String
    let amountCents: Int
    let amountLabel: String
    let paymentType: PaymentType?
    let requestedAt: Date?
    let confirmedAt: Date?
    let stage: BookingStage
}

struct RevenueSnapshot: Hashable {
    let confirmedCents: Int
    let confirmedLabel: String
    let confirmedCount: Int
    let confirmedItems: [RevenueLineItem]
    let pendingCents: Int
    let pendingLabel: String
    let pendingCount: Int
    let pendingItems: [RevenueLineItem]
    let completedCents: Int
    let completedLabel: String
    let completedCount: Int
    let completedItems: [RevenueLineItem]

    var totalEarnedCents: Int { confirmedCents + completedCents }
    var totalEarnedLabel: String {
        CurrencyValueFormatter.label(forCents: totalEarnedCents)
    }

    var isEmpty: Bool {
        confirmedCount == 0 && pendingCount == 0 && completedCount == 0
    }

    static let empty = RevenueSnapshot(
        confirmedCents: 0, confirmedLabel: "$0", confirmedCount: 0, confirmedItems: [],
        pendingCents: 0, pendingLabel: "$0", pendingCount: 0, pendingItems: [],
        completedCents: 0, completedLabel: "$0", completedCount: 0, completedItems: []
    )
}

enum ResponseRating: String {
    case fast, good, fair, slow

    var tone: AccentTone {
        switch self {
        case .fast: .sage
        case .good: .blue
        case .fair: .gold
        case .slow: .coral
        }
    }

    var label: String {
        switch self {
        case .fast: "Fast"
        case .good: "Good"
        case .fair: "Fair"
        case .slow: "Slow"
        }
    }
}

@MainActor
@Observable
final class VendorDashboardStore {
    @ObservationIgnored private let bookingService: any BookingServiceProtocol
    @ObservationIgnored private let analyticsService: any AnalyticsServiceProtocol
    @ObservationIgnored private let sessionStore: SessionStore
    let inboxStore: InboxStore
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var allBookings: [BookingRecord] = []

    var metrics: [MetricSummary] = []
    var revenueSnapshot: RevenueSnapshot = .empty
    var responseTimeLabel: String = "—"
    var responseRating: ResponseRating = .good
    var loadingState: LoadingState = .idle
    var insightsSummary: InsightsSummary?
    var externalPendingRequests: [ExternalBookingRequestRecord] = []
    var externalRequestActionInFlight: Set<UUID> = []

    struct InsightsSummary {
        let profileViews: Int
        let profileViewsTrend: Double
        let bookingConversion: Double
        let bookingConversionTrend: Double
    }

    // MARK: - Dashboard-ready computed properties

    var visibleLeadQueue: [BookingRequestSummary] {
        prioritizeLeadQueue(
            from: leadQueue
                .map { inboxStore.updatedSummary(from: $0, for: .vendor) }
                .filter {
                    !$0.stage.isConfirmed
                        && $0.stage != .active
                        && $0.stage != .cancelled
                        && $0.stage != .declined
                        && $0.stage != .accepted
                        && $0.stage != .paymentRequested
                }
        )
    }

    var dashboardLeadQueue: [BookingRequestSummary] {
        Array(visibleLeadQueue.prefix(3))
    }

    // MARK: - Computed lead lists (derived from InboxStore for live reactivity)

    var confirmedLeads: [BookingRequestSummary] {
        inboxStore.vendorScopedConversations()
            .filter { $0.stage == .paid }
            .map { makeSummary(from: $0) }
            .sorted { $0.dateLabel < $1.dateLabel }
    }

    var confirmedBookings: [BookingRequestSummary] {
        confirmedLeads
    }

    var leadQueue: [BookingRequestSummary] {
        let threads = inboxStore.vendorScopedConversations()
            .filter { !$0.stage.isConfirmed && !$0.stage.isTerminal && $0.stage != .active }
            .map { makeSummary(from: $0) }
        return prioritizeLeadQueue(from: threads)
    }

    var historyLeads: [BookingRequestSummary] {
        inboxStore.vendorScopedConversations()
            .filter { $0.stage == .completed || $0.stage.isTerminal }
            .map { makeSummary(from: $0) }
            .sorted { $0.dateLabel > $1.dateLabel }
    }

    init(
        bookingService: any BookingServiceProtocol,
        analyticsService: any AnalyticsServiceProtocol = UnavailableAnalyticsService(message: ""),
        sessionStore: SessionStore,
        inboxStore: InboxStore
    ) {
        self.bookingService = bookingService
        self.analyticsService = analyticsService
        self.sessionStore = sessionStore
        self.inboxStore = inboxStore
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        guard let vendorID = sessionStore.currentUserID else {
            reset()
            return
        }

        loadingState = .loading

        do {
            let bookings = try await bookingService.fetchVendorBookings(vendorID: vendorID)
            allBookings = bookings
            rebuild(bookings: bookings)
            hasLoaded = true
            loadingState = .loaded
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
        }

        await loadExternalPendingRequests()
    }

    func loadExternalPendingRequests() async {
        guard sessionStore.currentUserID != nil else {
            externalPendingRequests = []
            return
        }
        do {
            externalPendingRequests = try await bookingService.fetchPendingExternalBookingRequests()
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            AppLogger.booking.error("Failed to load external pending requests: \(error.localizedDescription, privacy: .public)")
        }
    }

    func acceptExternalRequest(_ requestID: UUID) async {
        guard !externalRequestActionInFlight.contains(requestID) else { return }
        externalRequestActionInFlight.insert(requestID)
        defer { externalRequestActionInFlight.remove(requestID) }

        do {
            _ = try await bookingService.acceptExternalBookingRequest(requestID: requestID)
            externalPendingRequests.removeAll { $0.id == requestID }
            await inboxStore.reload()
        } catch {
            AppLogger.booking.error("Accept external request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func declineExternalRequest(_ requestID: UUID, reason: String? = nil) async {
        guard !externalRequestActionInFlight.contains(requestID) else { return }
        externalRequestActionInFlight.insert(requestID)
        defer { externalRequestActionInFlight.remove(requestID) }

        do {
            try await bookingService.declineExternalBookingRequest(requestID: requestID, reason: reason)
            externalPendingRequests.removeAll { $0.id == requestID }
        } catch {
            AppLogger.booking.error("Decline external request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func reset() {
        metrics = []
        revenueSnapshot = .empty
        allBookings = []
        responseTimeLabel = "—"
        responseRating = .good
        insightsSummary = nil
        fetchedResponseMinutes = nil
        externalPendingRequests = []
        externalRequestActionInFlight = []
        hasLoaded = false
        loadingState = .idle
    }

    var todayRevenueSnapshot: RevenueSnapshot {
        revenueSnapshot(for: .today)
    }

    var todayTotalRevenueLabel: String {
        let snapshot = todayRevenueSnapshot
        let totalCents = snapshot.confirmedCents + snapshot.pendingCents + snapshot.completedCents
        return CurrencyValueFormatter.label(forCents: totalCents)
    }

    func revenueSnapshot(for timeRange: RevenueTimeRange) -> RevenueSnapshot {
        buildRevenueSnapshot(
            from: inboxStore.vendorScopedConversations(),
            bookings: allBookings,
            timeRange: timeRange
        )
    }

    // MARK: - Thread-to-summary mapping

    private func makeSummary(from thread: ConversationThread) -> BookingRequestSummary {
        let bookingByConversation = Dictionary(
            allBookings.map { ($0.conversationID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        let detail: String = switch thread.stage {
        case .accepted:
            "Request payment to lock in this booking."
        case .requested:
            "Open the request to accept it, decline it, or reply with questions."
        case .paid:
            "Booking confirmed and deposit received."
        case .completed:
            "Event completed."
        case .declined:
            "You declined this request."
        case .cancelled:
            "This booking was cancelled."
        default:
            "Keep the thread moving with one clear next step."
        }

        let booking = bookingByConversation[thread.id]
        let amountLabel: String
        if let cents = booking?.paymentRequestedAmountCents ?? booking?.totalAmountCents ?? booking?.depositAmountCents {
            amountLabel = CurrencyValueFormatter.label(forCents: cents)
        } else if let paymentAmount = thread.paymentRequest?.amountLabel {
            amountLabel = paymentAmount
        } else {
            amountLabel = "Open lead"
        }

        return BookingRequestSummary(
            conversationID: thread.id,
            vendorID: thread.vendorID,
            counterpartName: thread.hostName,
            title: thread.eventTitle,
            dateLabel: thread.eventDateLabel,
            detail: detail,
            amountLabel: amountLabel,
            stage: thread.stage
        )
    }

    private func rebuild(bookings: [BookingRecord]) {
        let needsResponseCount = leadQueue.filter(\.stage.requiresVendorAction).count
        let threads = inboxStore.vendorScopedConversations()
        let depositsPendingCount = threads.filter { $0.stage == .paymentRequested }.count

        metrics = [
            MetricSummary(
                title: "Needs response",
                value: "\(needsResponseCount)",
                detail: "leads awaiting your action",
                tone: needsResponseCount > 0 ? .gold : .sage
            ),
            MetricSummary(
                title: "Unread",
                value: "0",
                detail: "messages to triage",
                tone: .sage
            ),
            MetricSummary(
                title: "Deposits due",
                value: "\(depositsPendingCount)",
                detail: "awaiting deposit payment",
                tone: depositsPendingCount > 0 ? .blue : .sage
            ),
        ]

        revenueSnapshot = revenueSnapshot(for: .allTime)

        computeResponseTime()

        loadInsightsSummary()
    }

    private func computeResponseTime() {
        let activeConversationCount = inboxStore.vendorScopedConversations()
            .filter { !$0.stage.isTerminal && $0.stage != .active }
            .count

        if activeConversationCount == 0 {
            responseTimeLabel = "—"
            responseRating = .good
            return
        }

        // Use analytics data when available, fall back to estimate
        if insightsSummary != nil, let minutes = fetchedResponseMinutes {
            let hours = minutes / 60.0
            if hours < 1 {
                responseTimeLabel = "\(Int(minutes))m"
            } else {
                responseTimeLabel = String(format: "%.1fh", hours)
            }
            responseRating = responseRatingFor(minutes: minutes)
        } else {
            responseTimeLabel = "—"
            responseRating = .good
        }
    }

    @ObservationIgnored private var fetchedResponseMinutes: Double?

    private func responseRatingFor(minutes: Double) -> ResponseRating {
        switch minutes {
        case ..<30: return .fast
        case ..<60: return .good
        case ..<180: return .fair
        default: return .slow
        }
    }

    private func loadInsightsSummary() {
        Task { [weak self] in
            guard let self else { return }
            guard self.hasLoaded else { return }
            do {
                let insights = try await self.analyticsService.fetchInsights(period: .sevenDays)
                self.fetchedResponseMinutes = insights.conversion.avgResponseMinutes
                self.insightsSummary = InsightsSummary(
                    profileViews: insights.discovery.profileViews,
                    profileViewsTrend: insights.discovery.profileViewsTrend,
                    bookingConversion: insights.conversion.leadToBookingConversion,
                    bookingConversionTrend: insights.conversion.leadToBookingConversionTrend
                )

                if let minutes = insights.conversion.avgResponseMinutes {
                    let hours = minutes / 60.0
                    if hours < 1 {
                        self.responseTimeLabel = "\(Int(minutes))m"
                    } else {
                        self.responseTimeLabel = String(format: "%.1fh", hours)
                    }
                    self.responseRating = self.responseRatingFor(minutes: minutes)
                }
            } catch {
                // Insights are supplementary — don't affect dashboard loading
            }
        }
    }

    private func buildRevenueSnapshot(
        from threads: [ConversationThread],
        bookings: [BookingRecord],
        timeRange: RevenueTimeRange
    ) -> RevenueSnapshot {
        let bookingByConversation = Dictionary(
            bookings.map { ($0.conversationID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let cutoff = timeRange.cutoffDate

        func amountCents(for booking: BookingRecord) -> Int {
            booking.paymentRequestedAmountCents
                ?? booking.totalAmountCents
                ?? booking.depositAmountCents
                ?? 0
        }

        func lineItem(for thread: ConversationThread, booking: BookingRecord) -> RevenueLineItem {
            let cents = amountCents(for: booking)
            return RevenueLineItem(
                id: thread.id,
                conversationID: thread.id,
                hostName: thread.hostName,
                bookingDateLabel: thread.eventDateLabel,
                amountCents: cents,
                amountLabel: CurrencyValueFormatter.label(forCents: cents),
                paymentType: booking.paymentType.flatMap { PaymentType(rawValue: $0) },
                requestedAt: booking.paymentRequestedAt,
                confirmedAt: booking.paymentConfirmedAt,
                stage: thread.stage
            )
        }

        func passesTimeFilter(booking: BookingRecord, stage: BookingStage) -> Bool {
            guard let cutoff else { return true }
            switch stage {
            case .paid, .completed:
                return (booking.paymentConfirmedAt ?? booking.updatedAt ?? .distantPast) >= cutoff
            case .paymentRequested:
                return (booking.paymentRequestedAt ?? booking.updatedAt ?? .distantPast) >= cutoff
            default:
                return (booking.updatedAt ?? .distantPast) >= cutoff
            }
        }

        var confirmedItems: [RevenueLineItem] = []
        var pendingItems: [RevenueLineItem] = []
        var completedItems: [RevenueLineItem] = []

        for thread in threads {
            guard let booking = bookingByConversation[thread.id] else { continue }
            guard passesTimeFilter(booking: booking, stage: thread.stage) else { continue }

            switch thread.stage {
            case .paid:
                confirmedItems.append(lineItem(for: thread, booking: booking))
            case .paymentRequested:
                pendingItems.append(lineItem(for: thread, booking: booking))
            case .completed:
                completedItems.append(lineItem(for: thread, booking: booking))
            default:
                break
            }
        }

        let confirmedCents = confirmedItems.reduce(0) { $0 + $1.amountCents }
        let pendingCents = pendingItems.reduce(0) { $0 + $1.amountCents }
        let completedCents = completedItems.reduce(0) { $0 + $1.amountCents }

        return RevenueSnapshot(
            confirmedCents: confirmedCents,
            confirmedLabel: CurrencyValueFormatter.label(forCents: confirmedCents),
            confirmedCount: confirmedItems.count,
            confirmedItems: confirmedItems,
            pendingCents: pendingCents,
            pendingLabel: CurrencyValueFormatter.label(forCents: pendingCents),
            pendingCount: pendingItems.count,
            pendingItems: pendingItems,
            completedCents: completedCents,
            completedLabel: CurrencyValueFormatter.label(forCents: completedCents),
            completedCount: completedItems.count,
            completedItems: completedItems
        )
    }

    func prioritizeLeadQueue(from leadQueue: [BookingRequestSummary]) -> [BookingRequestSummary] {
        leadQueue.sorted { lhs, rhs in
            if lhs.stage.requiresVendorAction != rhs.stage.requiresVendorAction {
                return lhs.stage.requiresVendorAction
            }

            let lhsDate = sortDate(for: lhs.dateLabel) ?? .distantFuture
            let rhsDate = sortDate(for: rhs.dateLabel) ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }

            return lhs.counterpartName.localizedStandardCompare(rhs.counterpartName) == .orderedAscending
        }
    }

    func confirmedLead(forConversationID id: UUID) -> BookingRequestSummary? {
        confirmedLeads.first { $0.conversationID == id }
    }

    private func sortDate(for label: String) -> Date? {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, trimmedLabel != "Date pending" else { return nil }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let locale = Locale(identifier: "en_US_POSIX")

        for format in ["EEEE, MMMM d, yyyy", "EEEE, MMMM d", "MMMM d, yyyy", "MMMM d"] {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format

            guard var date = formatter.date(from: trimmedLabel) else { continue }
            if !format.contains("yyyy") {
                let currentYear = calendar.component(.year, from: startOfToday)
                guard let normalizedDate = calendar.date(
                    bySetting: .year,
                    value: currentYear,
                    of: date
                ) else {
                    return date
                }
                date = normalizedDate

                if date < startOfToday,
                   let nextYearDate = calendar.date(byAdding: .year, value: 1, to: date) {
                    date = nextYearDate
                }
            }

            return date
        }

        return nil
    }
}
