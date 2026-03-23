import Foundation

enum InsightsPeriod: Int, Sendable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90
}

protocol AnalyticsServiceProtocol: Sendable {
    func track(_ event: AnalyticsEvent)
    func flush() async
    func fetchInsights(period: InsightsPeriod) async throws -> VendorInsightsRecord
}
