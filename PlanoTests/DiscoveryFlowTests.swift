import Foundation
import Testing
@testable import Plano

struct DiscoveryFlowTests {
    @Test
    @MainActor
    func searchStaysInBlankDiscoveryStateWhenTheSelectedEventChanges() async throws {
        try await withIsolatedDefaults { defaults in
            let planner = HostPlanningStore(
                eventService: TestEventService(),
                vendorSearchService: TestVendorSearchService(),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let store = SearchStore(
                planner: planner,
                availabilityService: TestAvailabilityService(),
                defaults: defaults
            )

            await planner.load()

            #expect(store.selectedCategory == nil)
            #expect(store.isShowingDiscoveryState)

            let cocktailEventID = try #require(planner.events.first(where: { $0.type == .cocktailNight })?.id)
            planner.selectEvent(cocktailEventID)
            store.syncToSelectedEvent()

            #expect(store.selectedCategory == nil)
            #expect(store.isShowingDiscoveryState)
        }
    }

    @Test
    @MainActor
    func tagSearchFindsVendorsEvenWhenTheTagIsNotInTheName() async {
        await withIsolatedDefaults { defaults in
            let planner = HostPlanningStore(
                eventService: TestEventService(),
                vendorSearchService: TestVendorSearchService(),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let store = SearchStore(
                planner: planner,
                availabilityService: TestAvailabilityService(),
                defaults: defaults
            )

            await planner.load()
            store.query = "romantic"
            await store.load()

            #expect(store.visibleResults.contains(where: { $0.vendor.businessName == "Studio Petal" }))
        }
    }

    @Test
    @MainActor
    func suggestedPromptQueriesStillReturnVendors() async {
        await withIsolatedDefaults { defaults in
            let planner = HostPlanningStore(
                eventService: TestEventService(),
                vendorSearchService: TestVendorSearchService(),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let store = SearchStore(
                planner: planner,
                availabilityService: TestAvailabilityService(),
                defaults: defaults
            )

            await planner.load()
            store.selectedCategory = .photographer
            store.query = store.suggestedSearchText(for: .photographer)
            await store.load()

            #expect(store.visibleResults.contains(where: { $0.vendor.businessName == "North Frame" }))
        }
    }

    @Test
    @MainActor
    func searchIncludesVendorsOutsideTheSelectedEventCity() async {
        await withIsolatedDefaults { defaults in
            let outOfCityVendor = makeVendor(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000B301") ?? UUID(),
                name: "Montreal Floral Atelier",
                category: .decorator,
                basePriceCents: 290_000,
                pricingVisibility: .public,
                bookingMode: .requestOnly,
                paymentMode: .external,
                city: "Montreal",
                serviceArea: "Montreal + Laval"
            )

            let planner = HostPlanningStore(
                eventService: TestEventService(events: [FixtureData.events[0]]),
                vendorSearchService: TestVendorSearchService(vendorProfiles: FixtureData.vendorProfiles + [outOfCityVendor]),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let store = SearchStore(
                planner: planner,
                availabilityService: TestAvailabilityService(availableVendorIDs: FixtureData.vendorProfiles.map(\.id) + [outOfCityVendor.id]),
                defaults: defaults
            )

            await planner.load()
            store.selectedCategory = .decorator
            await store.load()

            #expect(store.visibleResults.contains(where: { $0.vendor.id == outOfCityVendor.id }))
        }
    }

    @Test
    @MainActor
    func searchWorksWithoutEventContext() async {
        await withIsolatedDefaults { defaults in
            let vendorProfiles = FixtureData.vendorProfiles + [
                makeVendor(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000B302") ?? UUID(),
                    name: "Golden Hour Photo",
                    category: .photographer,
                    basePriceCents: 360_000,
                    pricingVisibility: .public,
                    bookingMode: .requestOnly,
                    paymentMode: .external,
                    city: "Montreal",
                    serviceArea: "Montreal"
                ),
            ]

            let planner = HostPlanningStore(
                eventService: TestEventService(events: []),
                vendorSearchService: TestVendorSearchService(vendorProfiles: vendorProfiles),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let store = SearchStore(
                planner: planner,
                availabilityService: TestAvailabilityService(availableVendorIDs: vendorProfiles.map(\.id)),
                defaults: defaults
            )

            await planner.load()
            await store.load()

            #expect(store.hasEventContext == false)
            #expect(store.discoveryCategories == [.eventSpace, .decorator, .caterer, .photographer, .dj, .entertainer])
            #expect(store.suggestedSearchText(for: .photographer) == VendorCategory.photographer.title)

            store.selectedCategory = .photographer
            store.availabilityDate = Date()
            await store.load()

            #expect(store.visibleResults.contains(where: { $0.vendor.businessName == "Golden Hour Photo" }))
        }
    }

    @Test
    @MainActor
    func priceSortingPromotesBudgetFriendlyOptions() async {
        await withIsolatedDefaults { defaults in
            let planner = HostPlanningStore(
                eventService: TestEventService(),
                vendorSearchService: TestVendorSearchService(),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let store = SearchStore(
                planner: planner,
                availabilityService: TestAvailabilityService(),
                defaults: defaults
            )

            await planner.load()
            await store.load()

            store.sortMode = .priceLowToHigh
            #expect(store.visibleResults.first?.vendor.businessName == "Afterglow DJ Co.")
        }
    }

    @Test
    @MainActor
    func vendorProfileShortlistAndConversationActionsStayEventScoped() async throws {
        try await withIsolatedDefaults { defaults in
            let bookingService = TestBookingService(
                conversations: [FixtureData.conversationRecord()],
                messagesByConversation: [
                    FixtureData.conversationID: [
                        MessageRecord(
                            id: UUID(),
                            conversationID: FixtureData.conversationID,
                            senderRole: "vendor",
                            body: "Happy to review the event details.",
                            kind: "text",
                            createdAt: .now
                        ),
                    ],
                ]
            )
            let planner = HostPlanningStore(
                eventService: TestEventService(),
                vendorSearchService: TestVendorSearchService(),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )
            let hostIdentityPromptStore = HostIdentityPromptStore(authStore: authStore)
            let inboxStore = InboxStore(
                bookingService: bookingService,
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(),
                sessionStore: sessionStore,
                defaults: defaults
            )
            let router = AppRouter()
            let vendorProfileService = TestVendorProfileService()
            let vendorID = try #require(FixtureData.vendorProfiles.first(where: { $0.businessName == "Studio Petal" })?.id)

            await planner.load()
            planner.cacheDiscoveryVendors(FixtureData.vendorProfiles)

            sessionStore.applyAnonymousSession(
                AnonymousHostSession(
                    userID: FixtureData.hostID,
                    displayName: nil,
                    contactPhone: nil,
                    contactEmail: nil,
                    isLinkedToApple: false,
                    emailAddress: nil
                )
            )
            await inboxStore.loadConversations(for: .host)

            let store = VendorProfileStore(
                vendorID: vendorID,
                vendorProfileService: vendorProfileService,
                analyticsService: UnavailableAnalyticsService(message: "test"),
                availabilityService: TestAvailabilityService(),
                sessionStore: sessionStore
            )

            #expect(store.isSaved(planner: planner) == false)
            store.toggleSaved(planner: planner)
            #expect(store.isSaved(planner: planner) == true)

            store.openConversation(
                planner: planner,
                inboxStore: inboxStore,
                router: router,
                hostIdentityPromptStore: hostIdentityPromptStore
            )

            #expect(hostIdentityPromptStore.isPresented)
            #expect(router.inboxPath.isEmpty)

            sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))
            hostIdentityPromptStore.dismiss()

            let existingConversationID = try #require(
                inboxStore.existingConversationID(vendorID: vendorID, eventID: planner.selectedEventID)
            )

            store.openConversation()
            try? await Task.sleep(for: .milliseconds(50))

            #expect(router.selectedTab == .inbox)
            #expect(router.inboxPath == [.conversation(existingConversationID)])
        }
    }

    @Test
    @MainActor
    func homeViewExposesAllCategoriesWithoutAnEvent() async {
        let categories = VendorCategory.homeDisplayOrder.map { CategoryShortcut(category: $0) }
        #expect(categories.map(\.category) == VendorCategory.homeDisplayOrder)
    }

    @Test
    @MainActor
    func requestsStoreTeamSlotsReflectPlannedVendors() async throws {
        try await withIsolatedDefaults { defaults in
            let directVendor = try #require(FixtureData.vendorProfiles.first(where: { $0.category == .decorator }))
            let platformVendor = makeVendor(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000B101") ?? UUID(),
                name: "Harbour Catering Co.",
                category: .caterer,
                basePriceCents: 350_000,
                pricingVisibility: .public,
                bookingMode: .acceptOnline,
                paymentMode: .platform
            )

            let planner = HostPlanningStore(
                eventService: TestEventService(events: FixtureData.events),
                vendorSearchService: TestVendorSearchService(vendorProfiles: [directVendor, platformVendor]),
                plannedVendorService: TestPlannedVendorService(),
                defaults: defaults
            )
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAnonymousSession(FixtureData.anonymousSession(name: "Maya Chen"))
            let inboxStore = InboxStore(
                bookingService: TestBookingService(),
                messagingService: TestMessagingService(),
                vendorProfileService: TestVendorProfileService(vendorProfiles: [directVendor, platformVendor]),
                sessionStore: sessionStore,
                defaults: defaults
            )

            await planner.load()
            planner.cacheDiscoveryVendors([directVendor, platformVendor])
            planner.planVendor(platformVendor.id, for: .caterer, eventID: FixtureData.engagementEventID)

            let store = RequestsStore(planner: planner, inboxStore: inboxStore)

            #expect(store.hasEvents)
            #expect(!store.teamSlots.isEmpty)

            let catererSlot = try #require(store.teamSlots.first(where: { $0.category == .caterer }))
            #expect(catererSlot.vendor?.id == platformVendor.id)
        }
    }

    @MainActor
    private func makeVendor(
        id: UUID,
        name: String,
        category: VendorCategory,
        basePriceCents: Int,
        pricingVisibility: PricingVisibility,
        bookingMode: BookingMode,
        paymentMode: PaymentMode,
        searchMomentumScore: Int = 80,
        responseTime: String = "Responds in 1h",
        city: String = "Toronto",
        serviceArea: String = "Toronto + GTA"
    ) -> VendorProfile {
        VendorProfileRecord(
            userID: id,
            businessName: name,
            category: category.rawValue,
            bio: "Test vendor profile.",
            styleSummary: "Clear host-facing pricing and booking setup.",
            city: city,
            serviceArea: serviceArea,
            pricingModel: PricingModel.perEvent.rawValue,
            basePriceCents: basePriceCents,
            pricingVisibility: pricingVisibility.rawValue,
            availabilityMode: AvailabilityMode.showCalendar.rawValue,
            bookingMode: bookingMode.rawValue,
            paymentMode: paymentMode.rawValue,
            services: ["Signature service"],
            profileCompleteness: 90,
            tags: ["test"],
            onboardedAt: .now
        )
        .makeVendorProfile(
            responseTime: responseTime,
            ratingValue: 4.8,
            reviewCount: 12,
            badge: "Test fixture",
            availability: .available,
            services: ["Signature service"],
            packages: [],
            reviewHighlights: [],
            availabilitySummary: VendorAvailabilitySummary(
                nextOpeningLabel: "Open next week",
                leadTimeLabel: "2 weeks lead time",
                eventDateSupportLabel: "Available for your selected date.",
                supportsSelectedEventDate: true,
                windows: [AvailabilityWindow(label: "Selected date", state: .open)]
            ),
            repeatBookingRateLabel: "Reliable repeat bookings",
            searchMomentumScore: searchMomentumScore
        )
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
