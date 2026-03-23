import Testing
@testable import Plano

@MainActor
struct AnalyticsServiceTests {
    @Test("Track events accumulate in buffer")
    func trackEvents() {
        let service = MockAnalyticsService()

        service.track(AnalyticsEvent(eventType: .profileView, vendorID: FixtureData.vendorID))
        service.track(AnalyticsEvent(eventType: .galleryScroll, vendorID: FixtureData.vendorID))
        service.track(AnalyticsEvent(
            eventType: .searchImpression,
            vendorID: FixtureData.vendorID,
            metadata: ["query": "photographer", "position": "1"]
        ))

        #expect(service.trackedEvents.count == 3)
        #expect(service.trackedEvents[0].eventType == .profileView)
        #expect(service.trackedEvents[1].eventType == .galleryScroll)
        #expect(service.trackedEvents[2].eventType == .searchImpression)
        #expect(service.trackedEvents[2].metadata["query"] == "photographer")
    }

    @Test("Flush increments counter")
    func flushBehavior() async {
        let service = MockAnalyticsService()

        service.track(AnalyticsEvent(eventType: .profileView, vendorID: FixtureData.vendorID))
        await service.flush()

        #expect(service.flushCount == 1)
    }

    @Test("Fetch insights returns fixture when set")
    func fetchInsightsSuccess() async throws {
        let service = MockAnalyticsService()
        service.insightsToReturn = FixtureData.sampleInsights

        let result = try await service.fetchInsights(period: .thirtyDays)
        #expect(result.discovery.profileViews == 142)
        #expect(result.conversion.avgResponseMinutes == 45.0)
        #expect(result.revenue.totalRevenueCents == 425000)
    }

    @Test("Fetch insights throws when no data set")
    func fetchInsightsError() async {
        let service = MockAnalyticsService()

        do {
            _ = try await service.fetchInsights(period: .sevenDays)
            Issue.record("Expected error")
        } catch {
            // Expected
        }
    }

    @Test("UnavailableAnalyticsService track is no-op")
    func unavailableTrack() {
        let service = UnavailableAnalyticsService(message: "test")
        service.track(AnalyticsEvent(eventType: .profileView, vendorID: FixtureData.vendorID))
        // Should not crash
    }

    @Test("UnavailableAnalyticsService flush is no-op")
    func unavailableFlush() async {
        let service = UnavailableAnalyticsService(message: "test")
        await service.flush()
        // Should not crash
    }

    @Test("UnavailableAnalyticsService fetchInsights throws")
    func unavailableFetch() async {
        let service = UnavailableAnalyticsService(message: "Not configured")
        do {
            _ = try await service.fetchInsights(period: .sevenDays)
            Issue.record("Expected error")
        } catch {
            // Expected
        }
    }
}
