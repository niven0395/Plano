import Foundation
import Observation
import OSLog

enum SearchRatingFilter: CaseIterable, Identifiable, Hashable {
    case all
    case fourPointEight
    case fourPointNine

    var id: Self { self }

    var minimumValue: Double {
        switch self {
        case .all:
            0
        case .fourPointEight:
            4.8
        case .fourPointNine:
            4.9
        }
    }

    var title: String {
        switch self {
        case .all:
            "All ratings"
        case .fourPointEight:
            "4.8+"
        case .fourPointNine:
            "4.9+"
        }
    }
}

enum SearchSortMode: String, CaseIterable, Identifiable, Hashable {
    case recommended
    case topRated
    case fastestReply
    case availabilityFirst
    case priceLowToHigh

    var id: Self { self }

    var title: String {
        switch self {
        case .recommended:
            "Recommended"
        case .topRated:
            "Top rated"
        case .fastestReply:
            "Fastest reply"
        case .availabilityFirst:
            "Availability"
        case .priceLowToHigh:
            "Price: low to high"
        }
    }
}

struct SearchRankingReason: Hashable {
    let title: String
    let tone: AccentTone
}

struct SearchResultSnapshot: Identifiable, Hashable {
    let vendor: VendorProfile
    let rankingScore: Int
    let reasons: [SearchRankingReason]

    var id: UUID { vendor.id }
}

@MainActor
@Observable
final class SearchStore {
    private static let recentQueriesKey = "plano.search.recent-queries"
    private static let genericDiscoveryCategories: [VendorCategory] = [
        .eventSpace,
        .decorator,
        .caterer,
        .photographer,
        .dj,
        .entertainer,
    ]

    let planner: HostPlanningStore
    @ObservationIgnored private let availabilityService: any VendorAvailabilityServiceProtocol
    @ObservationIgnored private let analyticsService: any AnalyticsServiceProtocol
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var candidateVendors: [VendorProfile] = []
    @ObservationIgnored private var availableVendorIDs: Set<UUID> = []
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var scheduledRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var searchSequence = 0
    @ObservationIgnored private var isApplyingProgrammaticChanges = false
    @ObservationIgnored private var lastTrackedResultIDs: Set<UUID> = []

    var isRefreshing = false
    var filterChangeCounter = 0

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            recomputeVisibleResults()
            scheduleRemoteSearch(after: .milliseconds(500), showLoading: false)
        }
    }
    var selectedCategory: VendorCategory? {
        didSet {
            guard selectedCategory != oldValue else { return }
            filterChangeCounter += 1
            candidateVendors = []
            scheduleRemoteSearch(after: .zero, showLoading: !hasLoaded)
        }
    }
    var availabilityDate: Date? {
        didSet {
            guard availabilityDate != oldValue else { return }
            filterChangeCounter += 1
            refreshAvailability()
        }
    }
    var ratingFilter: SearchRatingFilter = .all {
        didSet {
            guard ratingFilter != oldValue else { return }
            filterChangeCounter += 1
            recomputeVisibleResults()
        }
    }
    var sortMode: SearchSortMode = .recommended {
        didSet {
            guard sortMode != oldValue else { return }
            filterChangeCounter += 1
            recomputeVisibleResults()
        }
    }
    var presentationState: SearchPresentationState
    var recentQueries: [String] {
        didSet {
            defaults.set(recentQueries, forKey: Self.recentQueriesKey)
        }
    }
    var visibleResults: [SearchResultSnapshot] = []

    init(
        planner: HostPlanningStore,
        availabilityService: any VendorAvailabilityServiceProtocol,
        analyticsService: any AnalyticsServiceProtocol = UnavailableAnalyticsService(message: ""),
        presentationState: SearchPresentationState = .live,
        defaults: UserDefaults = .standard
    ) {
        self.planner = planner
        self.availabilityService = availabilityService
        self.analyticsService = analyticsService
        self.defaults = defaults
        self.presentationState = presentationState
        recentQueries = defaults.stringArray(forKey: Self.recentQueriesKey) ?? []
    }

    var selectedEvent: PartyEvent {
        planner.selectedEvent
    }

    var hasEventContext: Bool {
        !planner.events.isEmpty
    }

    var activeFilterSummary: String {
        [
            selectedCategory?.title,
            availabilityDate != nil ? "Fits date" : nil,
            ratingFilter == .all ? nil : ratingFilter.title,
            sortMode == .recommended ? nil : sortMode.title,
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    var activeRefinementCount: Int {
        [
            selectedCategory != nil,
            availabilityDate != nil,
            ratingFilter != .all,
            sortMode != .recommended,
        ]
        .filter { $0 }
        .count
    }

    var isShowingDiscoveryState: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedCategory == nil &&
        availabilityDate == nil &&
        ratingFilter == .all &&
        sortMode == .recommended
    }

    var discoveryCategories: [VendorCategory] {
        Array(contextualRecommendedCategories.prefix(6))
    }

    var suggestedSearchCategories: [VendorCategory] {
        Array(discoveryCategories.prefix(4))
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        scheduledRefreshTask?.cancel()
        await performSearch(showLoading: false)
    }

    func reset() {
        scheduledRefreshTask?.cancel()
        candidateVendors = []
        availableVendorIDs = []
        performWithoutAutoRefresh {
            query = ""
            selectedCategory = nil
            availabilityDate = nil
            ratingFilter = .all
            sortMode = .recommended
        }
        visibleResults = []
        hasLoaded = false
        presentationState = .live
    }

    private func refreshAvailability() {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = Task {
            guard let date = availabilityDate else {
                availableVendorIDs = []
                recomputeVisibleResults()
                return
            }
            do {
                let ids = try await availabilityService.vendorsAvailable(
                    on: date,
                    category: selectedCategory,
                    city: nil
                )
                availableVendorIDs = Set(ids)
            } catch is CancellationError {
                return
            } catch {
                availableVendorIDs = []
            }
            recomputeVisibleResults()
        }
    }

    func toggleCategory(_ category: VendorCategory) {
        if selectedCategory == category {
            selectedCategory = nil
        } else {
            selectedCategory = category
        }
    }

    func applyRecentQuery(_ value: String) {
        query = value
        commitCurrentSearch()
    }

    func applyShortcutSearch(category: VendorCategory?, query: String) {
        performWithoutAutoRefresh {
            selectedCategory = category
            availabilityDate = nil
            ratingFilter = .all
            sortMode = .recommended
            self.query = query
        }

        commitCurrentSearch()
    }

    func applySuggestedSearch(for category: VendorCategory) {
        applyShortcutSearch(category: category, query: suggestedSearchText(for: category))
    }

    func suggestedSearchText(for category: VendorCategory) -> String {
        guard let event = activeContextEvent else {
            return category.title
        }

        return "\(event.type.searchPromptTitle) \(category.title.lowercased())"
    }

    func commitCurrentSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            scheduleRemoteSearch(after: .zero, showLoading: false)
            return
        }

        recentQueries.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentQueries.insert(trimmed, at: 0)
        recentQueries = Array(recentQueries.prefix(6))
        scheduleRemoteSearch(after: .zero, showLoading: false)
    }

    func clearFilters() {
        performWithoutAutoRefresh {
            query = ""
            selectedCategory = nil
            availabilityDate = nil
            ratingFilter = .all
            sortMode = .recommended
            presentationState = .live
        }

        scheduleRemoteSearch(after: .zero, showLoading: false)
    }

    func isSaved(_ vendorID: UUID) -> Bool {
        planner.isSavedVendor(vendorID)
    }

    func isSavePending(_ vendorID: UUID) -> Bool {
        planner.isSavedVendorSyncPending(vendorID)
    }

    func toggleSaved(_ vendorID: UUID) {
        planner.toggleSavedVendor(vendorID)
        recomputeVisibleResults()
    }

    func syncToSelectedEvent() {
        presentationState = .live
        scheduleRemoteSearch(after: .zero, showLoading: hasLoaded)
    }

    func retryPresentation() {
        scheduleRemoteSearch(after: .zero, showLoading: true)
    }

    private func matchesCategory(_ vendor: VendorProfile) -> Bool {
        selectedCategory.map { vendor.category == $0 } ?? true
    }

    private func matchesAvailability(_ vendor: VendorProfile) -> Bool {
        guard availabilityDate != nil else { return true }
        return availableVendorIDs.contains(vendor.id)
    }

    private func rankingScore(for vendor: VendorProfile, query: String) -> Int {
        var score = 0

        if planner.isSavedVendor(vendor.id) {
            score += 110
        }

        if hasEventContext && contextualRecommendedCategories.contains(vendor.category) {
            score += 45
        }

        if hasEventContext && availableVendorIDs.contains(vendor.id) {
            score += 35
        }

        if vendor.pricingVisibility == .public, vendor.priceValue > 0 {
            score += 8
        }

        switch vendor.availability {
        case .available:
            score += 18
        case .bookingFast:
            score += 10
        case .limited:
            score += 4
        }

        score += Int(vendor.ratingValue * 12)
        score += min(vendor.reviewCount, 120) / 3
        score += max(40 - vendor.responseMinutes, 0)
        score += vendor.profileCompleteness / 3
        score += vendor.searchMomentumScore / 3

        if !query.isEmpty {
            if vendor.businessName.localizedLowercase.contains(query) {
                score += 30
            }

            if vendor.styleSummary.localizedLowercase.contains(query) {
                score += 16
            }

            if vendor.tags.contains(where: { $0.localizedLowercase.contains(query) }) {
                score += 24
            }

            if vendor.city.localizedLowercase.contains(query) {
                score += 10
            }
        }

        return score
    }

    private func rankingReasons(for vendor: VendorProfile) -> [SearchRankingReason] {
        var reasons: [SearchRankingReason] = []

        if planner.isSavedVendor(vendor.id) {
            reasons.append(SearchRankingReason(title: "Saved shortlist", tone: .coral))
        }

        if hasEventContext && contextualRecommendedCategories.contains(vendor.category) {
            reasons.append(SearchRankingReason(title: "Strong event fit", tone: .blue))
        }

        if hasEventContext && availableVendorIDs.contains(vendor.id) {
            reasons.append(SearchRankingReason(title: "Fits event date", tone: .sage))
        }

        if vendor.responseMinutes <= 20 {
            reasons.append(SearchRankingReason(title: "Fast reply", tone: .gold))
        }

        if vendor.searchMomentumScore >= 85 {
            reasons.append(SearchRankingReason(title: "Popular now", tone: .sand))
        }

        if vendor.ratingValue >= 4.9 {
            reasons.append(SearchRankingReason(title: "Top reviews", tone: .blue))
        }

        if reasons.isEmpty {
            reasons.append(SearchRankingReason(title: vendor.availability.title, tone: vendor.availability.tone))
        }

        return Array(reasons.prefix(3))
    }

    private func compareResults(lhs: SearchResultSnapshot, rhs: SearchResultSnapshot) -> Bool {
        switch sortMode {
        case .recommended:
            if lhs.rankingScore != rhs.rankingScore {
                return lhs.rankingScore > rhs.rankingScore
            }
        case .topRated:
            if lhs.vendor.ratingValue != rhs.vendor.ratingValue {
                return lhs.vendor.ratingValue > rhs.vendor.ratingValue
            }
            if lhs.vendor.reviewCount != rhs.vendor.reviewCount {
                return lhs.vendor.reviewCount > rhs.vendor.reviewCount
            }
        case .fastestReply:
            if lhs.vendor.responseMinutes != rhs.vendor.responseMinutes {
                return lhs.vendor.responseMinutes < rhs.vendor.responseMinutes
            }
        case .availabilityFirst:
            if availableVendorIDs.contains(lhs.vendor.id) != availableVendorIDs.contains(rhs.vendor.id) {
                return availableVendorIDs.contains(lhs.vendor.id) && !availableVendorIDs.contains(rhs.vendor.id)
            }
            if lhs.vendor.availability != rhs.vendor.availability {
                return availabilityRank(lhs.vendor.availability) < availabilityRank(rhs.vendor.availability)
            }
        case .priceLowToHigh:
            if lhs.vendor.priceValue != rhs.vendor.priceValue {
                return lhs.vendor.priceValue < rhs.vendor.priceValue
            }
        }

        if lhs.rankingScore != rhs.rankingScore {
            return lhs.rankingScore > rhs.rankingScore
        }

        return lhs.vendor.businessName < rhs.vendor.businessName
    }

    private func availabilityRank(_ signal: AvailabilitySignal) -> Int {
        switch signal {
        case .available:
            return 0
        case .bookingFast:
            return 1
        case .limited:
            return 2
        }
    }

    private func performSearch(showLoading: Bool) async {
        let searchToken = nextSearchSequence()
        let request = VendorSearchRequest(
            text: query,
            category: selectedCategory,
            city: nil,
            eventDate: activeContextEvent?.date,
            limit: 48
        )

        if showLoading && !hasLoaded {
            presentationState = .loading
        } else if showLoading {
            isRefreshing = true
        }

        do {
            async let vendorsTask = planner.searchVendors(matching: request)
            let availableIDs: [UUID]

            if let date = availabilityDate {
                availableIDs = try await availabilityService.vendorsAvailable(
                    on: date,
                    category: selectedCategory,
                    city: nil
                )
            } else {
                availableIDs = []
            }

            let vendors = try await vendorsTask
            guard searchToken == searchSequence else { return }

            availableVendorIDs = Set(availableIDs)
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                candidateVendors = vendors
            } else {
                var existingByID = Dictionary(
                    candidateVendors.map { ($0.id, $0) },
                    uniquingKeysWith: { _, new in new }
                )
                for vendor in vendors {
                    existingByID[vendor.id] = vendor
                }
                candidateVendors = Array(existingByID.values)
            }
            recomputeVisibleResults()
            hasLoaded = true
            isRefreshing = false
            presentationState = .live

            let trimmedQuery = request.normalizedText
            if !trimmedQuery.isEmpty {
                let leadVendor = visibleResults.first?.vendor.businessName ?? "no immediate match"
                AppLogger.search.notice(
                    "Committed search query '\(trimmedQuery, privacy: .public)' with top result \(leadVendor, privacy: .public)"
                )
            }

            trackSearchImpressions(query: request.normalizedText)
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            guard searchToken == searchSequence else { return }
            isRefreshing = false
            if !hasLoaded {
                presentationState = .error(message: error.localizedDescription)
            }
        }
    }

    private func recomputeVisibleResults() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        let request = VendorSearchRequest(text: query, category: nil)
        let tokens = request.searchTokens
        let minimumMatches = request.minimumTokenMatches

        visibleResults = candidateVendors
            .filter { vendor in
                matchesCategory(vendor) &&
                matchesAvailability(vendor) &&
                vendor.ratingValue >= ratingFilter.minimumValue &&
                matchesTextTokens(vendor, tokens: tokens, minimumMatches: minimumMatches)
            }
            .map { vendor in
                SearchResultSnapshot(
                    vendor: vendor,
                    rankingScore: rankingScore(for: vendor, query: trimmedQuery),
                    reasons: rankingReasons(for: vendor)
                )
            }
            .sorted(by: compareResults)
    }

    private func matchesTextTokens(
        _ vendor: VendorProfile,
        tokens: [String],
        minimumMatches: Int
    ) -> Bool {
        guard !tokens.isEmpty else { return true }

        let haystack: String = [
            vendor.businessName,
            vendor.category.title,
            vendor.category.singularTitle,
            vendor.customCategoryName,
            vendor.bio,
            vendor.styleSummary,
            vendor.city,
            vendor.serviceArea,
            vendor.tags.joined(separator: " "),
            vendor.services.joined(separator: " "),
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .localizedLowercase

        let matchCount = Set(tokens).reduce(into: 0) { score, token in
            if haystack.contains(token) {
                score += 1
            }
        }

        return matchCount >= minimumMatches
    }

    private func scheduleRemoteSearch(
        after delay: Duration,
        showLoading: Bool
    ) {
        guard !isApplyingProgrammaticChanges else { return }

        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = Task { [weak self] in
            if delay != .zero {
                try? await Task.sleep(for: delay)
            }

            guard !Task.isCancelled else { return }
            await self?.performSearch(showLoading: showLoading)
        }
    }

    private var activeContextEvent: PartyEvent? {
        hasEventContext ? selectedEvent : nil
    }

    private var contextualRecommendedCategories: [VendorCategory] {
        guard let event = activeContextEvent else {
            return Self.genericDiscoveryCategories
        }

        var categories = planner.categories(for: event)
        if !categories.contains(.dj) {
            categories.append(.dj)
        }
        return categories
    }


    private func performWithoutAutoRefresh(_ updates: () -> Void) {
        isApplyingProgrammaticChanges = true
        updates()
        isApplyingProgrammaticChanges = false
    }

    private func nextSearchSequence() -> Int {
        searchSequence += 1
        return searchSequence
    }

    private func trackSearchImpressions(query: String) {
        let topResults = Array(visibleResults.prefix(20))
        let currentIDs = Set(topResults.map(\.vendor.id))
        guard currentIDs != lastTrackedResultIDs else { return }
        lastTrackedResultIDs = currentIDs

        for (index, result) in topResults.enumerated() {
            var metadata: [String: String] = ["position": "\(index + 1)"]
            if !query.isEmpty { metadata["query"] = query }
            metadata["category"] = result.vendor.category.rawValue

            analyticsService.track(AnalyticsEvent(
                eventType: .searchImpression,
                vendorID: result.vendor.id,
                metadata: metadata
            ))
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
