import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class CategoryBrowseStore {
    let category: VendorCategory
    private let planner: HostPlanningStore
    @ObservationIgnored private let availabilityService: any VendorAvailabilityServiceProtocol
    @ObservationIgnored private var candidateVendors: [VendorProfile] = []
    @ObservationIgnored private var availableVendorIDs: Set<UUID> = []
    @ObservationIgnored private var hasLoaded = false

    var filterState = CategoryBrowseFilterState()
    var photoVideoTab: PhotoVideoTab = .photos
    var presentationState: SearchPresentationState = .loading
    var visibleResults: [SearchResultSnapshot] = []
    var availableCities: [String] = []

    var searchQuery: String = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            recomputeVisibleResults()
        }
    }

    private(set) var displayedCount: Int = 4
    private(set) var isLoadingMore: Bool = false

    var displayedResults: [SearchResultSnapshot] {
        Array(visibleResults.prefix(displayedCount))
    }

    var canLoadMore: Bool {
        displayedCount < visibleResults.count
    }

    init(
        category: VendorCategory,
        planner: HostPlanningStore,
        availabilityService: any VendorAvailabilityServiceProtocol
    ) {
        self.category = category
        self.planner = planner
        self.availabilityService = availabilityService
    }

    var vendorCount: Int { visibleResults.count }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        if candidateVendors.isEmpty {
            presentationState = .loading
        }

        let request = VendorSearchRequest(
            text: "",
            category: category,
            city: nil,
            eventDate: nil,
            limit: 80
        )

        do {
            async let vendorsTask = planner.searchVendors(matching: request)

            let availableIDs: [UUID]
            if let date = filterState.availabilityDate {
                availableIDs = try await availabilityService.vendorsAvailable(
                    on: date,
                    category: category,
                    city: nil
                )
            } else {
                availableIDs = []
            }

            let vendors = try await vendorsTask
            availableVendorIDs = Set(availableIDs)
            candidateVendors = vendors
            availableCities = deriveCities(from: vendors)
            recomputeVisibleResults()
            presentationState = .live
            hasLoaded = true
        } catch is CancellationError {
            // Normal lifecycle
        } catch {
            presentationState = .error(message: error.localizedDescription)
        }
    }

    func retry() async {
        presentationState = .loading
        await load()
    }

    func applyFilters() {
        recomputeVisibleResults()
    }

    func refreshAvailability() async {
        guard let date = filterState.availabilityDate else {
            availableVendorIDs = []
            recomputeVisibleResults()
            return
        }
        do {
            let ids = try await availabilityService.vendorsAvailable(
                on: date,
                category: category,
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

    func resetFilters() {
        filterState.reset()
        recomputeVisibleResults()
    }

    func loadMore() {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            displayedCount += 4
            isLoadingMore = false
        }
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

    // MARK: - Private

    private func recomputeVisibleResults() {
        visibleResults = candidateVendors
            .filter { vendor in
                matchesTextQuery(vendor) && matchesCommonFilters(vendor) && filterState.matchesCategoryFilters(vendor, category: category) && matchesPhotoVideoTab(vendor)
            }
            .map { vendor in
                SearchResultSnapshot(
                    vendor: vendor,
                    rankingScore: rankingScore(for: vendor),
                    reasons: rankingReasons(for: vendor)
                )
            }
            .sorted(by: compareResults)
        displayedCount = 4
    }

    private func matchesPhotoVideoTab(_ vendor: VendorProfile) -> Bool {
        guard category == .photographer else { return true }
        guard case .photoVideo(let details) = vendor.categoryDetails else { return true }
        switch photoVideoTab {
        case .photos: return details.mediaType == .photo || details.mediaType == .both
        case .video: return details.mediaType == .video || details.mediaType == .both
        }
    }

    private func matchesTextQuery(_ vendor: VendorProfile) -> Bool {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        let lowered = query.lowercased()
        if vendor.businessName.lowercased().contains(lowered) { return true }
        if vendor.bio.lowercased().contains(lowered) { return true }
        if vendor.styleSummary.lowercased().contains(lowered) { return true }
        if vendor.tags.contains(where: { $0.lowercased().contains(lowered) }) { return true }
        return false
    }

    private func matchesCommonFilters(_ vendor: VendorProfile) -> Bool {
        if let city = filterState.selectedCity, vendor.city != city {
            return false
        }
        if vendor.ratingValue < filterState.ratingFilter.minimumValue {
            return false
        }
        if filterState.availabilityDate != nil {
            if !availableVendorIDs.contains(vendor.id) { return false }
        }
        return true
    }

    private func rankingScore(for vendor: VendorProfile) -> Int {
        var score = 0

        if planner.isSavedVendor(vendor.id) { score += 110 }
        if vendor.pricingVisibility == .public, vendor.priceValue > 0 { score += 8 }

        switch vendor.availability {
        case .available: score += 18
        case .bookingFast: score += 10
        case .limited: score += 4
        }

        score += Int(vendor.ratingValue * 12)
        score += min(vendor.reviewCount, 120) / 3
        score += max(40 - vendor.responseMinutes, 0)
        score += vendor.profileCompleteness / 3
        score += vendor.searchMomentumScore / 3

        return score
    }

    private func rankingReasons(for vendor: VendorProfile) -> [SearchRankingReason] {
        var reasons: [SearchRankingReason] = []

        if planner.isSavedVendor(vendor.id) {
            reasons.append(SearchRankingReason(title: "Saved shortlist", tone: .coral))
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
        switch filterState.sortMode {
        case .recommended:
            if lhs.rankingScore != rhs.rankingScore { return lhs.rankingScore > rhs.rankingScore }
        case .topRated:
            if lhs.vendor.ratingValue != rhs.vendor.ratingValue { return lhs.vendor.ratingValue > rhs.vendor.ratingValue }
            if lhs.vendor.reviewCount != rhs.vendor.reviewCount { return lhs.vendor.reviewCount > rhs.vendor.reviewCount }
        case .fastestReply:
            if lhs.vendor.responseMinutes != rhs.vendor.responseMinutes { return lhs.vendor.responseMinutes < rhs.vendor.responseMinutes }
        case .availabilityFirst:
            let lhsAvail = availableVendorIDs.contains(lhs.vendor.id)
            let rhsAvail = availableVendorIDs.contains(rhs.vendor.id)
            if lhsAvail != rhsAvail { return lhsAvail && !rhsAvail }
        case .priceLowToHigh:
            if lhs.vendor.priceValue != rhs.vendor.priceValue { return lhs.vendor.priceValue < rhs.vendor.priceValue }
        }

        if lhs.rankingScore != rhs.rankingScore { return lhs.rankingScore > rhs.rankingScore }
        return lhs.vendor.businessName < rhs.vendor.businessName
    }

    private func deriveCities(from vendors: [VendorProfile]) -> [String] {
        let citySet = Set(vendors.map(\.city))
        return citySet.sorted()
    }
}
