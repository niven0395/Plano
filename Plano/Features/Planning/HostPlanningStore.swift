import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class HostPlanningStore {
    private static let savedVendorKey = "plano.host.saved-vendor-ids"
    private static let onboardingKey = "plano.host.did-complete-onboarding"

    private let defaults: UserDefaults
    @ObservationIgnored private let vendorSearchService: any VendorSearchServiceProtocol
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var pendingSavedVendorIDs: Set<UUID> = []

    var loadingState: LoadingState = .idle
    var savedVendorIDs: Set<UUID> {
        didSet {
            defaults.set(savedVendorIDs.map(\.uuidString), forKey: Self.savedVendorKey)
        }
    }
    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Self.onboardingKey)
        }
    }
    var vendors: [VendorProfile]
    var recommendedVendors: [VendorProfile] = []

    init(
        vendorSearchService: any VendorSearchServiceProtocol,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.vendorSearchService = vendorSearchService
        vendors = []
        let storedSavedVendorIDs = (defaults.array(forKey: Self.savedVendorKey) as? [String] ?? [])
            .compactMap(UUID.init)
        savedVendorIDs = Set(storedSavedVendorIDs)
        hasCompletedOnboarding = defaults.object(forKey: Self.onboardingKey) as? Bool ?? false
    }

    var currentActionItems: [BookingRequestSummary] {
        []
    }

    var metrics: [MetricSummary] {
        [
            MetricSummary(title: "Pending", value: "\(currentActionItems.count)", detail: "active vendor decisions", tone: .gold),
            MetricSummary(title: "Saved", value: "\(savedVendorIDs.count)", detail: "shortlisted vendors", tone: .blue),
        ]
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        loadingState = .loading

        do {
            await refreshSavedVendorsFromBackend()
            await refreshRecommendedVendors()
            hasLoaded = true
            loadingState = .loaded
        }
    }

    func prepareForSignedOutState() {
        hasLoaded = false
        pendingSavedVendorIDs = []
        loadingState = .idle
        vendors = []
        recommendedVendors = []
        savedVendorIDs = []
        hasCompletedOnboarding = false
    }

    func filteredVendors(query: String, category: VendorCategory?) -> [VendorProfile] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase

        return vendors
            .filter { vendor in
                let matchesCategory = category.map { vendor.category == $0 } ?? true

                guard !trimmedQuery.isEmpty else {
                    return matchesCategory
                }

                let haystack = [
                    vendor.businessName,
                    vendor.displayCategoryTitle,
                    vendor.city,
                    vendor.serviceArea,
                    vendor.styleSummary,
                    vendor.badge,
                    vendor.intro,
                    vendor.tags.joined(separator: " "),
                ]
                .joined(separator: " ")
                .localizedLowercase

                return matchesCategory && haystack.contains(trimmedQuery)
            }
            .sorted(by: compareVendors)
    }

    func toggleSavedVendor(_ vendorID: UUID) {
        guard !pendingSavedVendorIDs.contains(vendorID) else { return }

        let shouldSave = !savedVendorIDs.contains(vendorID)
        let previousSavedVendorIDs = savedVendorIDs

        if shouldSave {
            savedVendorIDs.insert(vendorID)
        } else {
            savedVendorIDs.remove(vendorID)
        }

        pendingSavedVendorIDs.insert(vendorID)
        rebuildRecommendedVendorsFromCache()

        Task { [weak self] in
            await self?.persistSavedVendorChange(
                vendorID,
                shouldSave: shouldSave,
                previousSavedVendorIDs: previousSavedVendorIDs
            )
        }
    }

    func isSavedVendor(_ vendorID: UUID) -> Bool {
        savedVendorIDs.contains(vendorID)
    }

    func isSavedVendorSyncPending(_ vendorID: UUID) -> Bool {
        pendingSavedVendorIDs.contains(vendorID)
    }

    func vendor(id: UUID) -> VendorProfile? {
        vendors.first(where: { $0.id == id })
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func replayOnboarding() {
        hasCompletedOnboarding = false
    }

    func searchVendors(matching request: VendorSearchRequest) async throws -> [VendorProfile] {
        let records = try await vendorSearchService.searchVendors(matching: request)
        let mappedVendors = makeVendorProfiles(from: records)
        cacheDiscoveryVendors(mappedVendors)
        rebuildRecommendedVendorsFromCache()
        return mappedVendors
    }

    func rebuildRecommendedVendorsFromCache() {
        recommendedVendors = Array(
            vendors
                .sorted(by: compareVendors)
                .prefix(12)
        )
    }

    func cacheDiscoveryVendors(_ incomingVendors: [VendorProfile]) {
        guard !incomingVendors.isEmpty else { return }

        var mergedVendorsByID = Dictionary(uniqueKeysWithValues: vendors.map { ($0.id, $0) })
        for vendor in incomingVendors {
            mergedVendorsByID[vendor.id] = vendor
        }

        vendors = Array(mergedVendorsByID.values)
    }

    private func compareVendors(lhs: VendorProfile, rhs: VendorProfile) -> Bool {
        let lhsScore = rankingScore(for: lhs)
        let rhsScore = rankingScore(for: rhs)

        if lhsScore != rhsScore {
            return lhsScore > rhsScore
        }

        if lhs.ratingValue != rhs.ratingValue {
            return lhs.ratingValue > rhs.ratingValue
        }

        return lhs.businessName < rhs.businessName
    }

    private func rankingScore(for vendor: VendorProfile) -> Int {
        var score = 0

        if savedVendorIDs.contains(vendor.id) {
            score += 100
        }

        switch vendor.availability {
        case .available:
            score += 18
        case .bookingFast:
            score += 12
        case .limited:
            score += 8
        }

        score += Int(vendor.ratingValue * 10)
        score += min(vendor.reviewCount, 99) / 10
        score += max(50 - vendor.responseMinutes, 0)
        score += vendor.profileCompleteness / 3
        score += vendor.searchMomentumScore / 4

        return score
    }

    private func refreshSavedVendorsFromBackend() async {
        do {
            let backendSavedVendorIDs = try await vendorSearchService.fetchSavedVendorIDs()
            savedVendorIDs = backendSavedVendorIDs
        } catch {
            AppLogger.networking.error("Failed to load saved vendors: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshRecommendedVendors() async {
        do {
            let foundVendors = try await searchVendors(
                matching: VendorSearchRequest(
                    text: "",
                    category: nil,
                    limit: 36
                )
            )

            recommendedVendors = Array(foundVendors.sorted(by: compareVendors).prefix(12))
        } catch {
            rebuildRecommendedVendorsFromCache()
            AppLogger.search.error("Failed to refresh recommended vendors: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistSavedVendorChange(
        _ vendorID: UUID,
        shouldSave: Bool,
        previousSavedVendorIDs: Set<UUID>
    ) async {
        do {
            if shouldSave {
                try await vendorSearchService.saveVendor(vendorID)
            } else {
                try await vendorSearchService.unsaveVendor(vendorID)
            }
        } catch {
            savedVendorIDs = previousSavedVendorIDs
            rebuildRecommendedVendorsFromCache()
            AppLogger.search.error("Failed to sync saved vendor \(vendorID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        pendingSavedVendorIDs.remove(vendorID)
    }

    // MARK: - Vendor Profile Mapping

    private func makeVendorProfiles(from records: [VendorProfileRecord]) -> [VendorProfile] {
        records.map { record in
            let fallback = vendor(id: record.userID)

            return record.makeVendorProfile(
                fallbackCategory: fallback?.category ?? .entertainer,
                responseTime: fallback?.responseTime ?? "Responds in 1h",
                ratingValue: fallback?.ratingValue ?? 4.8,
                reviewCount: fallback?.reviewCount ?? 0,
                badge: fallback?.badge ?? "Fresh profile",
                intro: fallback?.intro ?? record.bio,
                availability: fallback?.availability ?? .bookingFast,
                services: record.services ?? fallback?.services ?? [],
                packages: fallback?.packages ?? [],
                galleryImages: fallback?.galleryImages ?? [],
                review: fallback?.review ?? VendorReviewSnippet(
                    author: "Recent host",
                    eventTypeLabel: "Private event",
                    quote: "Clear communication and a straightforward public profile."
                ),
                reviewHighlights: fallback?.reviewHighlights ?? [],
                availabilitySummary: fallback?.availabilitySummary ?? VendorAvailabilitySummary(
                    nextOpeningLabel: "Availability on request",
                    leadTimeLabel: "Lead time varies",
                    eventDateSupportLabel: "The vendor reviews dates directly once you reach out.",
                    supportsSelectedEventDate: true,
                    windows: []
                ),
                repeatBookingRateLabel: fallback?.repeatBookingRateLabel ?? "New listing",
                searchMomentumScore: fallback?.searchMomentumScore ?? 72
            )
        }
    }
}
