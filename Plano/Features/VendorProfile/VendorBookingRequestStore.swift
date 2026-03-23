import Foundation
import Observation

@MainActor
@Observable
final class VendorBookingRequestStore {
    let vendorID: UUID
    @ObservationIgnored private let bookingService: any BookingServiceProtocol
    @ObservationIgnored private let availabilityService: any VendorAvailabilityServiceProtocol
    @ObservationIgnored private let inboxStore: InboxStore
    @ObservationIgnored private let planner: HostPlanningStore
    @ObservationIgnored private let router: AppRouter

    var selectedBookingDate: Date?
    var bookingNote = ""
    var isSubmittingBooking = false
    var isPresentingBookingSheet = false
    var bookingError: String?
    var selectedTimeslot: TimeslotOption?
    var timeslotBookings: [VendorTimeslotBookingRecord] = []
    var availableTimeslots: [TimeslotOption] = []

    init(
        vendorID: UUID,
        bookingService: any BookingServiceProtocol,
        availabilityService: any VendorAvailabilityServiceProtocol,
        inboxStore: InboxStore,
        planner: HostPlanningStore,
        router: AppRouter
    ) {
        self.vendorID = vendorID
        self.bookingService = bookingService
        self.availabilityService = availabilityService
        self.inboxStore = inboxStore
        self.planner = planner
        self.router = router
    }

    var canSubmitBooking: Bool {
        if vendorHasTimeslots {
            return selectedBookingDate != nil && selectedTimeslot != nil
        }
        return selectedBookingDate != nil
    }

    var vendorHasTimeslots: Bool = false

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

    func loadTimeslotBookings(vendor: VendorProfile) async {
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
        vendorHasTimeslots = vendor.hasTimeslots
    }

    func submitBookingRequest(
        date: Date,
        note: String,
        vendor: VendorProfile
    ) async -> [VendorAvailabilityRecord]? {
        guard !isSubmittingBooking else { return nil }

        let selectedEvent = planner.selectedEvent
        let existingConversationID = inboxStore.existingConversationID(
            vendorID: vendor.id,
            eventID: selectedEvent.id
        )

        if let conversationID = existingConversationID {
            let stage = inboxStore.conversation(id: conversationID, for: .host)?.stage
            let blockingStages: Set<BookingStage> = [.requested, .accepted, .paymentRequested, .paid]
            if let stage, blockingStages.contains(stage) {
                bookingError = "You already have an active booking with this vendor for this event."
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

        do {
            let conversationID: UUID
            if let existing = existingConversationID {
                conversationID = existing
            } else {
                let event = planner.events.isEmpty ? nil : selectedEvent
                conversationID = try await inboxStore.startConversation(
                    with: vendor,
                    event: event
                )
            }

            _ = try await bookingService.submitBookingRequest(
                conversationID: conversationID,
                eventDate: date,
                note: note,
                requestedTimeStart: selectedTimeslot?.startTimeString,
                requestedTimeEnd: selectedTimeslot?.endTimeString,
                title: selectedEvent.title,
                budgetLabel: selectedEvent.budgetLabel,
                guestCountLabel: selectedEvent.guestCountLabel,
                requestedServices: nil
            )

            isPresentingBookingSheet = false
            selectedBookingDate = nil
            selectedTimeslot = nil
            bookingNote = ""
            isSubmittingBooking = false

            router.openConversation(conversationID)
        } catch {
            bookingError = error.localizedDescription
            isSubmittingBooking = false
        }

        return nil
    }
}
