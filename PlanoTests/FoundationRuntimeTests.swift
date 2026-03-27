import Foundation
import Testing
@testable import Plano

struct FoundationRuntimeTests {
    @Test
    @MainActor
    func authStoreBootstrapsAnonymousHostSessions() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()
            #expect(sessionStore.identityState == .anonymous)
            #expect(sessionStore.currentRole == .host)
            #expect(sessionStore.canBrowse)
            #expect(sessionStore.canMessage == false)

            sessionStore.applyAuthenticatedSession(FixtureData.vendorSession, preferredRole: .vendor)
            #expect(sessionStore.currentDisplayName == "Studio Petal")
            #expect(sessionStore.currentRole == .vendor)

            await authStore.signOut()

            #expect(sessionStore.identityState == .anonymous)
            #expect(sessionStore.currentRole == .host)
        }
    }

    @Test
    @MainActor
    func hostIdentitySubmissionUnlocksMessagingWithoutCreatingAnAccountGate() async throws {
        try await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()
            try await authStore.setHostIdentity(
                firstName: "Maya",
                lastName: "Chen",
                phone: "(416) 555-0100",
                email: "maya@example.com"
            )

            #expect(sessionStore.identityState == .identified(name: "Maya Chen"))
            #expect(sessionStore.currentDisplayName == "Maya Chen")
            #expect(sessionStore.canMessage)
        }
    }

    @Test
    @MainActor
    func hostPlanningLoadsMockEventsAndPersistsCreatedEvents() async throws {
        try await withIsolatedDefaults { defaults in
            let service = TestEventService()
            let vendorSearchService = TestVendorSearchService()
            let planner = HostPlanningStore(
                eventService: service,
                vendorSearchService: vendorSearchService,
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )

            #expect(planner.events.isEmpty)
            #expect(planner.selectedEvent.id == PartyEvent.placeholder.id)

            await planner.load()

            #expect(planner.loadingState == .loaded)
            #expect(planner.events.count == FixtureData.events.count)
            #expect(planner.selectedEvent.id == FixtureData.events.first?.id)
            #expect(planner.recommendedVendors.isEmpty == false)

            var draft = EventDraft()
            draft.title = "Sunset Dinner Party"
            draft.type = .dinnerParty
            draft.venue = "The Atrium"
            draft.city = "Toronto"
            draft.budgetLabel = "$7k - $11k"

            let createdEvent = await planner.addEvent(from: draft)
            let persistedEvents = try await service.fetchEvents()

            #expect(createdEvent?.title == "Sunset Dinner Party")
            #expect(planner.selectedEventID == createdEvent?.id)
            #expect(persistedEvents.contains(where: { $0.title == "Sunset Dinner Party" }))
        }
    }

    @Test
    func guestCountValueResolvesLegacyAndNumericInputs() {
        #expect(GuestCountValue.resolve(from: GuestCountTier.medium.rawValue) == GuestCountTier.medium.representativeCount)
        #expect(GuestCountValue.resolve(from: "64") == 64)
        #expect(GuestCountValue.resolve(from: "35-60 guests") == 47)
    }

    @Test
    func vendorProfileDraftCompletenessTracksKeySections() {
        var draft = VendorProfileDraft()
        #expect(draft.profileCompleteness == 10)

        draft.businessName = "North Frame"
        draft.city = "Toronto"
        draft.bio = "Film-inspired event photography."
        draft.tags = ["editorial", "soft flash"]
        draft.pricingModel = .perEvent
        draft.basePriceCents = 250_000
        draft.website = "northframe.studio"
        draft.instagramHandle = "northframe.studio"
        draft.galleryImages = [
            VendorGalleryImage(storagePath: "mock://vendor-galleries/test/1.jpg", displayOrder: 0, caption: "Reception coverage")
        ]
        draft.styleSummary = "Soft flash and restrained portraits."
        draft.serviceArea = "Toronto + GTA"

        #expect(draft.profileCompleteness == 100)
    }

    @Test
    func vendorProfileRecordDerivesWeeklyScheduleAndLegacyAvailabilityMode() {
        let record = VendorProfileRecord(
            userID: UUID(),
            businessName: "Studio Petal",
            availableDays: [Weekday.sunday.rawValue, Weekday.saturday.rawValue],
            schedulePreset: SchedulePreset.weekendsOnly.rawValue,
            leadTimeDays: 3,
            advanceBookingDays: 90,
            bookingMode: BookingMode.requestOnly.rawValue
        )

        let vendor = record.makeVendorProfile()

        #expect(vendor.weeklySchedule.preset == SchedulePreset.weekendsOnly)
        #expect(vendor.weeklySchedule.availableDays == Set([Weekday.sunday, Weekday.saturday]))
        #expect(vendor.leadTimeDays == 3)
        #expect(vendor.advanceBookingDays == 90)
        #expect(vendor.availabilityMode == AvailabilityMode.manualReview)
    }

    @Test
    func vendorProfileRecordFallsBackToCategoryLeadIntakeTemplate() {
        let record = VendorProfileRecord(
            userID: UUID(),
            businessName: "Studio Petal",
            category: VendorCategory.decorator.rawValue
        )

        let vendor = record.makeVendorProfile()

        #expect(vendor.enabledLeadIntakeQuestions.isEmpty == false)
        #expect(vendor.enabledLeadIntakeQuestions.allSatisfy { $0.id.hasPrefix("decorator-") })
    }

    @Test
    func pricingModelsExposeSearchLabels() {
        let vendor = VendorProfile(
            businessName: "North Frame",
            category: .dj,
            city: "Toronto",
            serviceArea: "Toronto + GTA",
            startingPrice: "",
            pricingModel: .perHour,
            basePriceCents: 60_000,
            hourlyRateCents: 15_000,
            minimumHours: 4,
            pricingVisibility: .public,
            responseTime: "Responds in 1h",
            ratingValue: 4.9,
            reviewCount: 12,
            badge: "Editorial",
            intro: "Soft flash coverage.",
            styleSummary: "Editorial portrait coverage.",
            availability: .available,
            services: [],
            packages: [],
            galleryHighlights: [],
            review: VendorReviewSnippet(author: "Maya", eventTypeLabel: "Birthday", quote: "Sharp coverage."),
            reviewHighlights: [],
            availabilitySummary: VendorAvailabilitySummary(
                nextOpeningLabel: "Open next month",
                leadTimeLabel: "2 weeks",
                eventDateSupportLabel: "Available for your date.",
                supportsSelectedEventDate: true,
                windows: []
            ),
            repeatBookingRateLabel: "Steady rebooks",
            profileCompleteness: 90,
            searchMomentumScore: 80
        )

        #expect(vendor.visibleStartingPriceLabel == "$150/hr (4 hr min)")
        #expect(vendor.visiblePricingDetailLabel == "$150/hr (4 hr min)")
    }

    @Test
    func draftDerivesAnchorPricingFromDifferentModels() {
        var hourlyDraft = VendorProfileDraft()
        hourlyDraft.category = .dj
        hourlyDraft.pricingModel = .perHour
        hourlyDraft.hourlyRateCents = 12_500
        hourlyDraft.minimumHours = 4

        #expect(hourlyDraft.computedBasePriceCents == 50_000)

        var customDraft = VendorProfileDraft()
        customDraft.pricingModel = .custom
        customDraft.serviceItems = [
            VendorServiceItem(title: "Backdrop styling", priceCents: 120_000, description: "", displayOrder: 0),
            VendorServiceItem(title: "Entry install", priceCents: 80_000, description: "", displayOrder: 1),
        ]

        #expect(customDraft.computedBasePriceCents == 80_000)
        #expect(customDraft.displayPriceLabel == "$800 - $1,200")
    }

    @MainActor
    private func withIsolatedDefaults(_ body: (UserDefaults) async throws -> Void) async rethrows {
        let suiteName = "PlanoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try await body(defaults)
    }
}
