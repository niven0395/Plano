import Foundation
import Testing
@testable import Plano

struct VendorOnboardingStoreTests {
    @Test
    @MainActor
    func slideOneValidationRequiresBusinessName() async {
        await withIsolatedDefaults { defaults in
            let store = makeStore(defaults: defaults)

            #expect(store.isSlideOneValid == false)

            store.businessName = "  "
            #expect(store.isSlideOneValid == false)

            store.businessName = "Studio Luna"
            #expect(store.isSlideOneValid)
        }
    }

    @Test
    @MainActor
    func submitSlideOneCreatesProfileAndAdvances() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAuthenticatedSession(
                AuthenticatedUserProfile(
                    userID: FixtureData.vendorID,
                    emailAddress: "test@example.com",
                    displayName: "Test User",
                    vendorDisplayName: nil
                ),
                preferredRole: .host
            )
            sessionStore.requiresVendorOnboarding = true

            let store = makeStore(defaults: defaults, sessionStore: sessionStore)
            store.businessName = "Studio Luna"
            store.businessEmail = "hello@studioluna.com"
            store.selectedCategory = .photographer

            #expect(store.currentSlide == 0)
            #expect(store.slideOneSubmitted == false)

            await store.submitSlideOne()

            #expect(store.slideOneSubmitted)
            #expect(store.currentSlide == 1)
            #expect(sessionStore.requiresVendorOnboarding)
        }
    }

    @Test
    @MainActor
    func skipAdvancesWithoutSaving() async {
        await withIsolatedDefaults { defaults in
            let store = makeStore(defaults: defaults)
            store.slideOneSubmitted = true
            store.currentSlide = 1

            store.skipCurrentSlide()

            #expect(store.currentSlide == 2)
        }
    }

    @Test
    @MainActor
    func skipOnLastSlideFinishesOnboarding() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.requiresVendorOnboarding = true

            let store = makeStore(defaults: defaults, sessionStore: sessionStore)
            store.currentSlide = VendorOnboardingStore.totalSlides - 1
            store.slideOneSubmitted = true

            store.skipCurrentSlide()

            #expect(sessionStore.requiresVendorOnboarding == false)
        }
    }

    @Test
    @MainActor
    func navigationBoundsAreRespected() async {
        await withIsolatedDefaults { defaults in
            let store = makeStore(defaults: defaults)

            store.goBack()
            #expect(store.currentSlide == 0)

            store.currentSlide = VendorOnboardingStore.totalSlides - 1
            store.advanceSlide()
            #expect(store.currentSlide == VendorOnboardingStore.totalSlides - 1)
        }
    }

    @Test
    @MainActor
    func categoryChangeResetsCategoryDetails() async {
        await withIsolatedDefaults { defaults in
            let store = makeStore(defaults: defaults)
            store.categoryDetails = .photoVideo(PhotoVideoDetails(mediaType: .both))

            store.handleCategoryChange(to: .caterer)

            if case .catering(let details) = store.categoryDetails {
                #expect(details.isEmpty)
            } else {
                Issue.record("Expected catering details after category change")
            }
        }
    }

    @Test
    @MainActor
    func cancelDismissesOnboarding() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.requiresVendorOnboarding = true

            let store = makeStore(defaults: defaults, sessionStore: sessionStore)
            store.cancel()

            #expect(sessionStore.requiresVendorOnboarding == false)
        }
    }

    @Test
    @MainActor
    func isLastSlideReportsCorrectly() async {
        await withIsolatedDefaults { defaults in
            let store = makeStore(defaults: defaults)

            #expect(store.isLastSlide == false)

            store.currentSlide = VendorOnboardingStore.totalSlides - 1
            #expect(store.isLastSlide)
        }
    }

    // MARK: - Helpers

    private func makeStore(
        defaults: UserDefaults,
        sessionStore: SessionStore? = nil
    ) -> VendorOnboardingStore {
        let session = sessionStore ?? SessionStore(defaults: defaults)
        return VendorOnboardingStore(
            vendorProfileService: TestVendorProfileService(),
            mediaService: TestMediaService(),
            imageProcessor: ImageProcessor(),
            imageCache: ImageCache(),
            sessionStore: session
        )
    }

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
