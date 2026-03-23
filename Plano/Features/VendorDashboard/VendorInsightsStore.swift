import Foundation
import Observation
import OSLog

enum InsightsPeriodSelection: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"

    var id: Self { self }

    var period: InsightsPeriod {
        switch self {
        case .sevenDays: .sevenDays
        case .thirtyDays: .thirtyDays
        case .ninetyDays: .ninetyDays
        }
    }
}

@MainActor
@Observable
final class VendorInsightsStore {
    @ObservationIgnored private let analyticsService: any AnalyticsServiceProtocol
    @ObservationIgnored private var hasLoaded = false

    var selectedPeriod: InsightsPeriodSelection = .thirtyDays {
        didSet {
            guard selectedPeriod != oldValue else { return }
            Task { await load() }
        }
    }
    var insights: VendorInsightsRecord?
    var loadingState: LoadingState = .idle

    init(analyticsService: any AnalyticsServiceProtocol) {
        self.analyticsService = analyticsService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        loadingState = insights == nil ? .loading : .loaded

        do {
            let result = try await analyticsService.fetchInsights(period: selectedPeriod.period)
            insights = result
            hasLoaded = true
            loadingState = .loaded
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            if !hasLoaded {
                loadingState = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Formatted display values

    var profileViewsLabel: String {
        guard let insights else { return "—" }
        return "\(insights.discovery.profileViews)"
    }

    var impressionsLabel: String {
        guard let insights else { return "—" }
        return "\(insights.discovery.searchImpressions)"
    }

    var ctrLabel: String {
        guard let insights else { return "—" }
        return String(format: "%.1f%%", insights.discovery.clickThroughRate * 100)
    }

    var saveRateLabel: String {
        guard let insights else { return "—" }
        return String(format: "%.1f%%", insights.engagement.saveRate * 100)
    }

    var messageRateLabel: String {
        guard let insights else { return "—" }
        return String(format: "%.1f%%", insights.conversion.messageInitiationRate * 100)
    }

    var bookingRateLabel: String {
        guard let insights else { return "—" }
        return String(format: "%.1f%%", insights.conversion.bookingRequestRate * 100)
    }

    var conversionRateLabel: String {
        guard let insights else { return "—" }
        return String(format: "%.1f%%", insights.conversion.leadToBookingConversion * 100)
    }

    var responseTimeLabel: String {
        guard let insights, let minutes = insights.conversion.avgResponseMinutes else { return "—" }
        let hours = minutes / 60.0
        if hours < 1 { return "\(Int(minutes))m" }
        return String(format: "%.1fh", hours)
    }

    var revenueLabel: String {
        guard let insights else { return "—" }
        return CurrencyValueFormatter.label(forCents: insights.revenue.totalRevenueCents)
    }

    var avgBookingValueLabel: String {
        guard let insights else { return "—" }
        return CurrencyValueFormatter.label(forCents: insights.revenue.avgBookingValueCents)
    }

    var bookingVolumeLabel: String {
        guard let insights else { return "—" }
        return "\(insights.revenue.bookingVolume)"
    }
}
