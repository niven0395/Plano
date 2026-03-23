import Foundation
import Observation

@MainActor
@Observable
final class EventsStore {
    @ObservationIgnored private let bookingService: any BookingServiceProtocol
    @ObservationIgnored private let sessionStore: SessionStore
    @ObservationIgnored private var hasLoadedVendorEvents = false

    var loadingState: LoadingState = .idle
    var vendorEvents: [EventSummary] = []

    init(
        bookingService: any BookingServiceProtocol,
        sessionStore: SessionStore
    ) {
        self.bookingService = bookingService
        self.sessionStore = sessionStore
    }

    func loadIfNeeded() async {
        guard !hasLoadedVendorEvents else { return }
        await loadVendorEvents()
    }

    func loadVendorEvents() async {
        guard let vendorID = sessionStore.currentUserID else {
            vendorEvents = []
            loadingState = .idle
            return
        }

        loadingState = .loading

        do {
            let records = try await bookingService.fetchVendorConversations(vendorID: vendorID)
            vendorEvents = records
                .filter { BookingStage.fromDatabaseValue($0.stage).isConfirmed }
                .map { record in
                    EventSummary(
                        id: record.eventID ?? record.id,
                        title: record.eventTitle ?? "Direct inquiry",
                        kind: VendorCategory(rawValue: record.vendorCategory)?.title ?? "Vendor work",
                        dateLabel: record.eventDateLabel ?? "Date pending",
                        venue: record.eventContextLine ?? "Location pending",
                        guestCountLabel: record.eventContextLine ?? "Guest count pending",
                        completionText: record.stage.replacingOccurrences(of: "_", with: " ").capitalized,
                        progress: BookingStage.fromDatabaseValue(record.stage).isConfirmed ? 1 : 0.72,
                        stage: BookingStage.fromDatabaseValue(record.stage)
                    )
                }
                .sorted { $0.dateLabel < $1.dateLabel }
            hasLoadedVendorEvents = true
            loadingState = .loaded
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    func invalidate() {
        hasLoadedVendorEvents = false
    }

    func reset() {
        vendorEvents = []
        hasLoadedVendorEvents = false
        loadingState = .idle
    }
}
