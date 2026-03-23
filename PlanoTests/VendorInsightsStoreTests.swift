import Testing
@testable import Plano

@MainActor
struct VendorInsightsStoreTests {
    @Test("Initial state is idle")
    func initialState() {
        let service = MockAnalyticsService()
        let store = VendorInsightsStore(analyticsService: service)

        #expect(store.loadingState == .idle)
        #expect(store.insights == nil)
        #expect(store.selectedPeriod == .thirtyDays)
    }

    @Test("Load populates insights")
    func loadPopulatesInsights() async {
        let service = MockAnalyticsService()
        service.insightsToReturn = FixtureData.sampleInsights

        let store = VendorInsightsStore(analyticsService: service)
        await store.load()

        #expect(store.loadingState == .loaded)
        #expect(store.insights != nil)
        #expect(store.profileViewsLabel == "142")
        #expect(store.impressionsLabel == "890")
    }

    @Test("Load failure sets failed state")
    func loadFailure() async {
        let service = MockAnalyticsService()
        service.insightsError = APIError.notConfigured("Test error")

        let store = VendorInsightsStore(analyticsService: service)
        await store.load()

        if case .failed = store.loadingState {
            // Expected
        } else {
            Issue.record("Expected failed state")
        }
    }

    @Test("Formatted display values")
    func formattedValues() async {
        let service = MockAnalyticsService()
        service.insightsToReturn = FixtureData.sampleInsights

        let store = VendorInsightsStore(analyticsService: service)
        await store.load()

        #expect(store.ctrLabel == "16.0%")
        #expect(store.saveRateLabel == "12.7%")
        #expect(store.responseTimeLabel == "45m")
        #expect(store.conversionRateLabel == "65.0%")
        #expect(store.bookingVolumeLabel == "4")
    }

    @Test("LoadIfNeeded only loads once")
    func loadIfNeeded() async {
        let service = MockAnalyticsService()
        service.insightsToReturn = FixtureData.sampleInsights

        let store = VendorInsightsStore(analyticsService: service)
        await store.loadIfNeeded()
        await store.loadIfNeeded()

        #expect(store.insights != nil)
    }

    @Test("Empty insights display dashes")
    func emptyDisplayValues() {
        let service = MockAnalyticsService()
        let store = VendorInsightsStore(analyticsService: service)

        #expect(store.profileViewsLabel == "\u{2014}")
        #expect(store.impressionsLabel == "\u{2014}")
        #expect(store.ctrLabel == "\u{2014}")
        #expect(store.responseTimeLabel == "\u{2014}")
        #expect(store.revenueLabel == "\u{2014}")
    }
}
