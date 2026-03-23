import Foundation
import Observation

@MainActor
@Observable
final class VendorProfileStore {
    let vendorID: UUID
    private let vendorProfileService: any VendorProfileServiceProtocol
    private let analyticsService: any AnalyticsServiceProtocol
    private let availabilityService: any VendorAvailabilityServiceProtocol
    let sessionStore: SessionStore
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var hasTrackedGallery = false

    var vendor: VendorProfile?
    var availabilityRecords: [VendorAvailabilityRecord] = []
    var loadingState: LoadingState = .idle
    var isRefreshing = false

    init(
        vendorID: UUID,
        vendorProfileService: any VendorProfileServiceProtocol,
        analyticsService: any AnalyticsServiceProtocol,
        availabilityService: any VendorAvailabilityServiceProtocol,
        sessionStore: SessionStore
    ) {
        self.vendorID = vendorID
        self.vendorProfileService = vendorProfileService
        self.analyticsService = analyticsService
        self.availabilityService = availabilityService
        self.sessionStore = sessionStore
    }

    var isOwnVendorProfile: Bool {
        sessionStore.currentUserID == vendorID
    }

    var canInitiateConversation: Bool {
        sessionStore.currentRole == .host && !isOwnVendorProfile
    }

    var shouldShowStats: Bool {
        guard let vendor else { return false }
        return vendor.reviewCount > 0 || vendor.visibleStartingPriceLabel != nil
    }

    var shouldShowAbout: Bool {
        guard let vendor else { return false }
        return !vendor.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !vendor.styleSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var shouldShowCategoryDetails: Bool {
        guard let vendor else { return false }
        guard let details = vendor.categoryDetails else { return false }
        return !details.isEmpty
    }

    var shouldShowServices: Bool {
        !(vendor?.services.isEmpty ?? true)
    }

    var shouldShowGallery: Bool {
        !(vendor?.galleryImages.isEmpty ?? true)
    }

    var shouldShowReviews: Bool {
        !(vendor?.reviewHighlights.isEmpty ?? true)
    }

    var shouldShowPolicies: Bool {
        !(vendor?.policies.isEmpty ?? true)
    }

    var shouldShowSocial: Bool {
        !(vendor?.socialLinks.isEmpty ?? true)
    }

    var shouldShowTags: Bool {
        !(vendor?.tags.isEmpty ?? true)
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        if vendor == nil {
            loadingState = .loading
        } else {
            isRefreshing = true
        }

        do {
            if let record = try await vendorProfileService.fetchPublicVendorProfile(vendorID: vendorID) {
                async let galleryImages = vendorProfileService.fetchGalleryImages(vendorID: vendorID)
                async let serviceItems = vendorProfileService.fetchServiceItems(vendorID: vendorID)

                let advanceDays = record.advanceBookingDays ?? 180
                async let records = availabilityService.fetchAvailability(
                    vendorID: vendorID,
                    from: .now,
                    to: Calendar.current.date(byAdding: .day, value: advanceDays, to: .now) ?? .now
                )

                let fallback = vendor
                vendor = record.makeVendorProfile(
                    fallbackCategory: fallback?.category ?? .entertainer,
                    responseTime: fallback?.responseTime ?? "Responds in 1h",
                    ratingValue: fallback?.ratingValue ?? 4.8,
                    reviewCount: fallback?.reviewCount ?? 0,
                    badge: fallback?.badge ?? "New listing",
                    intro: fallback?.intro ?? record.bio,
                    availability: fallback?.availability ?? .bookingFast,
                    services: record.services ?? fallback?.services ?? [],
                    serviceItems: try await serviceItems,
                    packages: fallback?.packages ?? [],
                    galleryImages: try await galleryImages,
                    review: fallback?.review ?? VendorReviewSnippet(
                        author: "Recent host",
                        eventTypeLabel: "Private event",
                        quote: "Clean communication and a clear public profile."
                    ),
                    reviewHighlights: fallback?.reviewHighlights ?? [],
                    availabilitySummary: fallback?.availabilitySummary ?? VendorAvailabilitySummary(
                        nextOpeningLabel: "Availability on request",
                        leadTimeLabel: "Lead time varies",
                        eventDateSupportLabel: "Availability is confirmed once the vendor reviews your date.",
                        supportsSelectedEventDate: true,
                        windows: []
                    ),
                    repeatBookingRateLabel: fallback?.repeatBookingRateLabel ?? "New listing",
                    searchMomentumScore: fallback?.searchMomentumScore ?? 72
                )

                availabilityRecords = try await records
            }

            hasLoaded = true
            isRefreshing = false
            loadingState = .loaded

            analyticsService.track(AnalyticsEvent(
                eventType: .profileView,
                vendorID: vendorID
            ))
        } catch {
            isRefreshing = false
            loadingState = .failed(error.localizedDescription)
        }
    }

    func toggleSaved(planner: HostPlanningStore) {
        let wasSaved = planner.isSavedVendor(vendorID)
        planner.toggleSavedVendor(vendorID)
        analyticsService.track(AnalyticsEvent(
            eventType: wasSaved ? .vendorUnsaved : .vendorSaved,
            vendorID: vendorID
        ))
    }

    func isSaved(planner: HostPlanningStore) -> Bool {
        planner.isSavedVendor(vendorID)
    }

    func trackGalleryEngagement() {
        guard !hasTrackedGallery else { return }
        hasTrackedGallery = true
        analyticsService.track(AnalyticsEvent(
            eventType: .galleryScroll,
            vendorID: vendorID
        ))
    }

    func trackSocialLinkClick(kind: String) {
        analyticsService.track(AnalyticsEvent(
            eventType: .socialLinkClick,
            vendorID: vendorID,
            metadata: ["kind": kind]
        ))
    }

    func openConversation(
        planner: HostPlanningStore,
        inboxStore: InboxStore,
        router: AppRouter,
        hostIdentityPromptStore: HostIdentityPromptStore
    ) {
        guard sessionStore.canBrowse else { return }
        guard canInitiateConversation else { return }

        if sessionStore.needsNamePrompt {
            hostIdentityPromptStore.present { [weak self] in
                self?.beginConversation(planner: planner, inboxStore: inboxStore, router: router)
            }
            return
        }

        beginConversation(planner: planner, inboxStore: inboxStore, router: router)
    }

    private func beginConversation(planner: HostPlanningStore, inboxStore: InboxStore, router: AppRouter) {
        guard let vendor else { return }
        let event = planner.events.isEmpty ? nil : planner.selectedEvent

        Task { [weak self] in
            guard let self else { return }

            do {
                let conversationID = try await inboxStore.startConversation(
                    with: vendor,
                    event: event
                )
                router.openConversation(conversationID)
            } catch {
                await MainActor.run {
                    self.loadingState = .failed(error.localizedDescription)
                }
            }
        }
    }
}
