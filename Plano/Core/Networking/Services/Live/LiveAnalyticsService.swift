import Foundation
import OSLog
#if canImport(Supabase)
import Supabase

actor LiveAnalyticsService: AnalyticsServiceProtocol {
    private let client: SupabaseClient
    private var buffer: [AnalyticsEvent] = []
    private var flushTask: Task<Void, Never>?
    private static let maxBufferSize = 50
    private static let flushThreshold = 20
    private static let flushInterval: Duration = .seconds(30)

    init(client: SupabaseClient) {
        self.client = client
        schedulePeriodicFlush()
    }

    nonisolated func track(_ event: AnalyticsEvent) {
        Task { await enqueue(event) }
    }

    func flush() async {
        await sendBuffer()
    }

    func fetchInsights(period: InsightsPeriod) async throws -> VendorInsightsRecord {
        let result: VendorInsightsRecord = try await client.functions.invoke(
            "fetch-vendor-insights",
            options: FunctionInvokeOptions(body: ["period_days": period.rawValue]),
            decoder: ISO8601Decoding.decoder
        )
        return result
    }

    private func enqueue(_ event: AnalyticsEvent) {
        buffer.append(event)

        if buffer.count >= Self.maxBufferSize {
            buffer.removeFirst(buffer.count - Self.maxBufferSize)
        }

        if buffer.count >= Self.flushThreshold {
            Task { await sendBuffer() }
        }
    }

    private func sendBuffer() {
        guard !buffer.isEmpty else { return }
        let events = buffer
        buffer = []

        Task {
            do {
                let payload = AnalyticsBatchPayload(
                    events: events.map { event in
                        AnalyticsBatchPayload.EventPayload(
                            eventType: event.eventType.rawValue,
                            vendorID: event.vendorID.uuidString,
                            eventID: event.eventID?.uuidString,
                            metadata: event.metadata.isEmpty ? nil : event.metadata
                        )
                    }
                )

                try await client.functions.invoke(
                    "ingest-analytics",
                    options: FunctionInvokeOptions(body: payload)
                )

                AppLogger.analytics.notice(
                    "Flushed \(events.count, privacy: .public) analytics events"
                )
            } catch {
                AppLogger.analytics.warning(
                    "Analytics flush failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func schedulePeriodicFlush() {
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.flushInterval)
                guard !Task.isCancelled else { break }
                await self?.sendBuffer()
            }
        }
    }
}

private struct AnalyticsBatchPayload: Encodable {
    let events: [EventPayload]

    struct EventPayload: Encodable {
        let eventType: String
        let vendorID: String
        let eventID: String?
        let metadata: [String: String]?

        enum CodingKeys: String, CodingKey {
            case eventType = "event_type"
            case vendorID = "vendor_id"
            case eventID = "event_id"
            case metadata
        }
    }
}
#else
actor LiveAnalyticsService: AnalyticsServiceProtocol {
    init(client: Any? = nil) {}

    nonisolated func track(_ event: AnalyticsEvent) {}

    func flush() async {}

    func fetchInsights(period: InsightsPeriod) async throws -> VendorInsightsRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }
}
#endif
