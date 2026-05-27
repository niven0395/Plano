import Foundation
import Testing
@testable import Plano

struct HostPlanningStoreTests {
    @Test
    @MainActor
    func loadCachesRecommendedVendorsFromSearchService() async {
        await withIsolatedDefaults { defaults in
            let store = HostPlanningStore(
                vendorSearchService: TestVendorSearchService(),
                defaults: defaults
            )

            #expect(store.vendors.isEmpty)
            #expect(store.recommendedVendors.isEmpty)

            await store.load()

            #expect(store.loadingState == .loaded)
            #expect(store.vendors.count == FixtureData.vendorProfiles.count)
            #expect(store.recommendedVendors.first?.businessName == "Studio Petal")
        }
    }

    @Test
    @MainActor
    func savedVendorsLoadFromBackendAndPersistLocally() async {
        await withIsolatedDefaults { defaults in
            let vendorID = FixtureData.secondVendorID
            let searchService = TestVendorSearchService(savedVendorIDs: [vendorID])
            let store = HostPlanningStore(
                vendorSearchService: searchService,
                defaults: defaults
            )

            await store.load()

            #expect(store.isSavedVendor(vendorID))

            let restoredStore = HostPlanningStore(
                vendorSearchService: TestVendorSearchService(),
                defaults: defaults
            )

            #expect(restoredStore.isSavedVendor(vendorID))
        }
    }

    @Test
    @MainActor
    func filteredVendorsRespectQueryAndCategory() async {
        await withIsolatedDefaults { defaults in
            let store = HostPlanningStore(
                vendorSearchService: TestVendorSearchService(),
                defaults: defaults
            )

            await store.load()

            let decoratorResults = store.filteredVendors(query: "garden", category: .decorator)
            let photographerResults = store.filteredVendors(query: "garden", category: .photographer)

            #expect(decoratorResults.map(\.businessName) == ["Studio Petal"])
            #expect(photographerResults.isEmpty)
        }
    }

    @MainActor
    private func withIsolatedDefaults(_ body: (UserDefaults) async -> Void) async {
        let suiteName = "PlanoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        await body(defaults)
    }
}
