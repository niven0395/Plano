import Foundation
import Observation

@MainActor
@Observable
final class VendorBookingRequestStore {
    let vendorID: UUID
    @ObservationIgnored private let bookingService: any BookingServiceProtocol
    @ObservationIgnored private let availabilityService: any VendorAvailabilityServiceProtocol
    @ObservationIgnored private let inboxStore: InboxStore
    @ObservationIgnored private let router: AppRouter

    var selectedBookingDate: Date?
    var bookingNote = ""
    var isSubmittingBooking = false
    var isPresentingBookingSheet = false
    var bookingError: String?
    var selectedTimeslot: TimeslotOption?
    var timeslotBookings: [VendorTimeslotBookingRecord] = []
    var availableTimeslots: [TimeslotOption] = []
    var schedulingMode: SchedulingMode = .calendar
    var requestedStartTime: Date?
    var requestedEndTime: Date?
    var intakeAnswers: [LeadIntakeAnswer] = []

    init(
        vendorID: UUID,
        bookingService: any BookingServiceProtocol,
        availabilityService: any VendorAvailabilityServiceProtocol,
        inboxStore: InboxStore,
        router: AppRouter
    ) {
        self.vendorID = vendorID
        self.bookingService = bookingService
        self.availabilityService = availabilityService
        self.inboxStore = inboxStore
        self.router = router
    }

    var canSubmitBooking: Bool {
        switch schedulingMode {
        case .calendar:
            selectedBookingDate != nil
        case .timeslots:
            selectedBookingDate != nil && selectedTimeslot != nil
        case .eventTimeRange:
            selectedBookingDate != nil
                && requestedStartTime != nil
                && requestedEndTime != nil
        }
    }

    var vendorHasTimeslots: Bool {
        schedulingMode == .timeslots
    }

    var vendorUsesEventTimeRange: Bool {
        schedulingMode == .eventTimeRange
    }

    func updateTimeslotsForSelectedDate(vendor: VendorProfile) {
        guard vendor.hasTimeslots, let date = selectedBookingDate else {
            availableTimeslots = []
            return
        }
        availableTimeslots = vendor.timeslotConfig.generatedSlots(
            for: date,
            existingBookings: timeslotBookings
        )
    }

    func initializeEventTimeRangeDefaults() {
        guard schedulingMode == .eventTimeRange else { return }
        if requestedStartTime == nil {
            requestedStartTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))
        }
        if requestedEndTime == nil {
            requestedEndTime = Calendar.current.date(from: DateComponents(hour: 17, minute: 0))
        }
    }

    func loadTimeslotBookings(vendor: VendorProfile) async {
        schedulingMode = vendor.schedulingMode
        initializeEventTimeRangeDefaults()
        guard vendor.hasTimeslots else { return }
        let advanceDays = vendor.timeslotConfig.rollingWindowDays
        do {
            timeslotBookings = try await availabilityService.fetchTimeslotBookings(
                vendorID: vendorID,
                from: .now,
                to: Calendar.current.date(byAdding: .day, value: advanceDays, to: .now) ?? .now
            )
        } catch {
            timeslotBookings = []
        }
    }

    func submitBookingRequest(
        date: Date,
        note: String,
        vendor: VendorProfile
    ) async -> [VendorAvailabilityRecord]? {
        guard !isSubmittingBooking else { return nil }

        let existingConversationID = inboxStore.existingConversationID(vendorID: vendor.id)

        if let conversationID = existingConversationID {
            let stage = inboxStore.conversation(id: conversationID, for: .host)?.stage
            let blockingStages: Set<BookingStage> = [.requested, .accepted, .paymentRequested, .paid]
            if let stage, blockingStages.contains(stage) {
                bookingError = "You already have an active booking with this vendor."
                return nil
            }
        }

        isSubmittingBooking = true
        bookingError = nil

        do {
            let dateCheck = try await availabilityService.checkAvailability(vendorID: vendorID, on: date)
            if !dateCheck.isAvailable {
                let advanceDays = vendor.advanceBookingDays
                let refreshed = try await availabilityService.fetchAvailability(
                    vendorID: vendorID,
                    from: .now,
                    to: Calendar.current.date(byAdding: .day, value: advanceDays, to: .now) ?? .now
                )
                bookingError = "This date is no longer available. Please select a different date."
                isSubmittingBooking = false
                return refreshed
            }
        } catch {
            bookingError = "Unable to verify availability. Please try again."
            isSubmittingBooking = false
            return nil
        }

        let resolvedTimeStart: String?
        let resolvedTimeEnd: String?

        switch schedulingMode {
        case .timeslots:
            resolvedTimeStart = selectedTimeslot?.startTimeString
            resolvedTimeEnd = selectedTimeslot?.endTimeString
        case .eventTimeRange:
            resolvedTimeStart = requestedStartTime.map(Self.formatTimeString)
            resolvedTimeEnd = requestedEndTime.map(Self.formatTimeString)
        case .calendar:
            resolvedTimeStart = nil
            resolvedTimeEnd = nil
        }

        do {
            let conversationID: UUID
            if let existing = existingConversationID {
                conversationID = existing
            } else {
                conversationID = try await inboxStore.startConversation(
                    with: vendor
                )
            }

            let normalizedAnswers = intakeAnswers
                .map { $0.normalized() }
                .filter(\.hasValue)

            _ = try await bookingService.submitBookingRequest(
                conversationID: conversationID,
                eventDate: date,
                note: note,
                requestedTimeStart: resolvedTimeStart,
                requestedTimeEnd: resolvedTimeEnd,
                title: "Direct inquiry",
                budgetLabel: nil,
                guestCountLabel: "",
                requestedServices: nil,
                intakeAnswers: normalizedAnswers.isEmpty ? nil : normalizedAnswers
            )

            await inboxStore.loadConversations(for: .host)

            isPresentingBookingSheet = false
            selectedBookingDate = nil
            selectedTimeslot = nil
            requestedStartTime = nil
            requestedEndTime = nil
            bookingNote = ""
            intakeAnswers = []
            isSubmittingBooking = false

            router.openConversation(conversationID)
        } catch {
            bookingError = error.localizedDescription
            isSubmittingBooking = false
        }

        return nil
    }

    private static func formatTimeString(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d:00", components.hour ?? 0, components.minute ?? 0)
    }
}
