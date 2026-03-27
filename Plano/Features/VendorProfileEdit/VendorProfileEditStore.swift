import Foundation
import Observation
import OSLog
import SwiftUI
import UIKit

enum VendorProfileEditSection: String, CaseIterable, Identifiable {
    case basicInfo
    case about
    case categoryDetails
    case servicesPricing
    case leadIntake
    case gallery
    case policies
    case availability
    case socialContact
    case tagsKeywords

    var id: Self { self }

    var title: String {
        switch self {
        case .basicInfo:
            "Basic Info"
        case .about:
            "About"
        case .categoryDetails:
            "Category Details"
        case .servicesPricing:
            "Services & Pricing"
        case .leadIntake:
            "Lead Intake"
        case .gallery:
            "Gallery"
        case .policies:
            "Policies"
        case .availability:
            "Availability & Booking"
        case .socialContact:
            "Social & Contact"
        case .tagsKeywords:
            "Tags & Keywords"
        }
    }

    var subtitle: String {
        switch self {
        case .basicInfo:
            "Business name, category, and city"
        case .about:
            "Bio, style summary, and service area"
        case .categoryDetails:
            "Industry-specific details hosts need to know"
        case .servicesPricing:
            "Pricing model, visibility, and key services"
        case .leadIntake:
            "Booking questions hosts answer before sending a request"
        case .gallery:
            "Portfolio images for conversion"
        case .policies:
            "Cancellation, weather, travel, and custom terms"
        case .availability:
            "Schedule, booking mode, and date overrides"
        case .socialContact:
            "Instagram, website, phone, and TikTok"
        case .tagsKeywords:
            "Search keywords that expand discovery"
        }
    }

    func dynamicTitle(for category: VendorCategory) -> String {
        guard self == .categoryDetails else { return title }
        return CategoryDetails.empty(for: category).sectionTitle
    }

    func dynamicSubtitle(for category: VendorCategory) -> String {
        guard self == .categoryDetails else { return subtitle }
        return "Details specific to \(category.title.lowercased())"
    }
}

struct VendorProfileSectionStatus: Identifiable, Hashable {
    let section: VendorProfileEditSection
    let isComplete: Bool

    var id: VendorProfileEditSection { section }
}

@MainActor
@Observable
final class VendorProfileEditStore {
    private let vendorProfileService: any VendorProfileServiceProtocol
    private let mediaService: any MediaServiceProtocol
    private let availabilityService: any VendorAvailabilityServiceProtocol
    private let imageProcessor: ImageProcessor
    private let imageCache: ImageCache
    private let sessionStore: SessionStore
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var pendingOverrideDates: Set<Date> = []

    var draft = VendorProfileDraft()
    var loadingState: LoadingState = .idle
    var lastSaveOutcome: SaveOutcome = .idle
    var availabilityRecords: [VendorAvailabilityRecord] = []
    var timeslotBookings: [VendorTimeslotBookingRecord] = []
    var pendingUploads: [ImageUploadProgress] = []

    init(
        vendorProfileService: any VendorProfileServiceProtocol,
        mediaService: any MediaServiceProtocol,
        availabilityService: any VendorAvailabilityServiceProtocol,
        imageProcessor: ImageProcessor,
        imageCache: ImageCache,
        sessionStore: SessionStore
    ) {
        self.vendorProfileService = vendorProfileService
        self.mediaService = mediaService
        self.availabilityService = availabilityService
        self.imageProcessor = imageProcessor
        self.imageCache = imageCache
        self.sessionStore = sessionStore
    }

    var profileCompleteness: Int {
        draft.profileCompleteness
    }

    var sectionStatuses: [VendorProfileSectionStatus] {
        let hasAvailabilitySchedule = !draft.availableDays.isEmpty
        let hasBookingPreferences = draft.bookingMode != .inquiryOnly || draft.paymentMode != .external

        return [
            .init(section: .basicInfo, isComplete: !draft.businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draft.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
            .init(section: .about, isComplete: !draft.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.styleSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.serviceArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
            .init(section: .categoryDetails, isComplete: draft.categoryDetails.map { !$0.isEmpty } ?? false),
            .init(section: .servicesPricing, isComplete: draft.computedBasePriceCents != nil || !draft.services.isEmpty),
            .init(section: .leadIntake, isComplete: !draft.enabledLeadIntakeQuestions.isEmpty),
            .init(section: .gallery, isComplete: !draft.galleryImages.isEmpty),
            .init(section: .policies, isComplete: !draft.policies.isEmpty),
            .init(section: .availability, isComplete: hasAvailabilitySchedule && hasBookingPreferences),
            .init(section: .socialContact, isComplete: !draft.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
            .init(section: .tagsKeywords, isComplete: !draft.tags.isEmpty),
        ]
    }

    var nextRecommendation: String {
        let hasCategoryDetails = draft.categoryDetails.map { !$0.isEmpty } ?? false

        switch profileCompleteness {
        case ..<30:
            return "Add a bio and a photo to start appearing in search with more trust."
        case 30..<60:
            return "Add pricing and availability so hosts can make faster decisions."
        case 60..<90:
            if !hasCategoryDetails {
                return "Add \(draft.category.singularTitle.lowercased()) details to help hosts understand your offering."
            } else {
                return "Almost there. Add social links and search tags."
            }
        default:
            return "Your profile is strong."
        }
    }

    func reset() {
        hasLoaded = false
        draft = VendorProfileDraft()
        availabilityRecords = []
        timeslotBookings = []
        pendingOverrideDates = []
        loadingState = .idle
        lastSaveOutcome = .idle
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        guard sessionStore.isVendorAuthenticated else {
            loadingState = .idle
            return
        }

        loadingState = .loading

        do {
            let vendorID = sessionStore.currentUserID ?? UUID()
            async let record = vendorProfileService.fetchOwnVendorProfile()
            async let galleryImages = vendorProfileService.fetchGalleryImages(vendorID: vendorID)
            async let serviceItems = vendorProfileService.fetchServiceItems(vendorID: vendorID)
            async let availability = availabilityService.fetchAvailability(
                vendorID: sessionStore.currentUserID ?? UUID(),
                from: .now,
                to: availabilityFetchEndDate()
            )

            if let record = try await record {
                draft.apply(
                    record: record,
                    galleryImages: try await galleryImages,
                    serviceItems: try await serviceItems
                )
            } else if let profile = sessionStore.authenticatedProfile {
                draft.businessName = profile.vendorDisplayName ?? ""
            }

            if draft.leadIntakeQuestions.isEmpty {
                draft.leadIntakeQuestions = LeadIntakeTemplateLibrary.defaultQuestions(for: draft.category)
            }

            availabilityRecords = try await availability

            if draft.schedulingMode == .timeslots {
                timeslotBookings = try await availabilityService.fetchTimeslotBookings(
                    vendorID: sessionStore.currentUserID ?? UUID(),
                    from: .now,
                    to: availabilityFetchEndDate()
                )
            }

            hasLoaded = true
            loadingState = .loaded
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    func save() async {
        guard let userID = sessionStore.currentUserID else { return }
        loadingState = .loading

        do {
            let record = draft.makeRecord(userID: userID)
            let savedRecord = try await vendorProfileService.updateVendorProfile(record)
            try await vendorProfileService.replaceGalleryImages(draft.galleryImages, vendorID: userID)
            try await vendorProfileService.replaceServiceItems(draft.preparedServiceItems, vendorID: userID)
            draft.apply(
                record: savedRecord,
                galleryImages: draft.galleryImages,
                serviceItems: draft.preparedServiceItems
            )

            if let existing = sessionStore.authenticatedProfile {
                sessionStore.completeVendorOnboarding(
                    with: AuthenticatedUserProfile(
                        userID: existing.userID,
                        emailAddress: existing.emailAddress,
                        displayName: existing.displayName,
                        vendorDisplayName: savedRecord.businessName
                    )
                )
            }

            hasLoaded = true
            loadingState = .loaded
            lastSaveOutcome = .saved
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
            lastSaveOutcome = .failed(error.localizedDescription)
        }
    }

    func uploadProfileImage(data: Data) async {
        guard let userID = sessionStore.currentUserID else { return }
        loadingState = .loading

        do {
            let variants = try await imageProcessor.processVariants(from: data)

            if let existing = draft.profileImagePath {
                try await mediaService.deleteImage(path: existing)
            }

            let storagePath = try await mediaService.uploadImageVariants(variants, vendorID: userID)
            draft.profileImagePath = storagePath

            // Stage in cache for instant display
            if let thumbData = variants[.thumbnail], let image = UIImage(data: thumbData) {
                await imageCache.stageLocalImage(image, for: storagePath)
            }

            await save()
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
            lastSaveOutcome = .failed(error.localizedDescription)
        }
    }

    func removeProfileImage() async {
        loadingState = .loading

        do {
            if let existing = draft.profileImagePath {
                try await mediaService.deleteImage(path: existing)
            }
            draft.profileImagePath = nil
            await save()
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
            lastSaveOutcome = .failed(error.localizedDescription)
        }
    }

    func uploadListingImage(data: Data) async {
        guard let userID = sessionStore.currentUserID else { return }
        loadingState = .loading

        do {
            let variants = try await imageProcessor.processVariants(from: data)

            if let existing = draft.listingImagePath {
                try await mediaService.deleteImage(path: existing)
            }

            let storagePath = try await mediaService.uploadImageVariants(variants, vendorID: userID)
            draft.listingImagePath = storagePath

            if let thumbData = variants[.thumbnail], let image = UIImage(data: thumbData) {
                await imageCache.stageLocalImage(image, for: storagePath)
            }

            await save()
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
            lastSaveOutcome = .failed(error.localizedDescription)
        }
    }

    func removeListingImage() async {
        loadingState = .loading

        do {
            if let existing = draft.listingImagePath {
                try await mediaService.deleteImage(path: existing)
            }
            draft.listingImagePath = nil
            await save()
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
            lastSaveOutcome = .failed(error.localizedDescription)
        }
    }

    func addGalleryImage(data: Data) async {
        guard let userID = sessionStore.currentUserID else { return }
        guard draft.galleryImages.count < 5 else { return }

        // Create local preview for optimistic display
        let localImage = UIImage(data: data)
        let progress = ImageUploadProgress(localImage: localImage ?? UIImage())
        pendingUploads.append(progress)

        do {
            progress.state = .processing
            let variants = try await imageProcessor.processVariants(from: data)

            progress.state = .uploading(progress: 0.5)
            let storagePath = try await mediaService.uploadImageVariants(variants, vendorID: userID)

            // Stage in cache for instant display
            if let thumbData = variants[.thumbnail], let image = UIImage(data: thumbData) {
                await imageCache.stageLocalImage(image, for: storagePath)
            }

            draft.galleryImages.append(
                VendorGalleryImage(
                    storagePath: storagePath,
                    displayOrder: draft.galleryImages.count,
                    caption: "Portfolio image \(draft.galleryImages.count + 1)"
                )
            )

            progress.state = .uploading(progress: 0.9)
            try await vendorProfileService.replaceGalleryImages(draft.galleryImages, vendorID: userID)

            progress.storagePath = storagePath
            progress.state = .complete
            pendingUploads.removeAll { $0.id == progress.id }
            lastSaveOutcome = .saved
        } catch is CancellationError {
            pendingUploads.removeAll { $0.id == progress.id }
        } catch {
            progress.state = .failed(error.localizedDescription)
            lastSaveOutcome = .failed(error.localizedDescription)
        }
    }

    func removeGalleryImage(_ image: VendorGalleryImage) async {
        guard let userID = sessionStore.currentUserID else { return }
        loadingState = .loading

        do {
            try await mediaService.deleteImage(path: image.storagePath)
            draft.galleryImages.removeAll { $0.id == image.id }
            draft.galleryImages = draft.galleryImages.enumerated().map { index, item in
                VendorGalleryImage(
                    id: item.id,
                    storagePath: item.storagePath,
                    displayOrder: index,
                    caption: item.caption
                )
            }
            try await vendorProfileService.replaceGalleryImages(draft.galleryImages, vendorID: userID)
            loadingState = .loaded
            lastSaveOutcome = .saved
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
            lastSaveOutcome = .failed(error.localizedDescription)
        }
    }

    func availabilityStatus(for date: Date) -> VendorAvailabilityStatus? {
        let targetDay = Calendar.current.startOfDay(for: date)
        return availabilityRecords.first(where: {
            guard let recordDate = $0.date else { return false }
            return Calendar.current.isDate(recordDate, inSameDayAs: targetDay)
        })
        .flatMap { VendorAvailabilityStatus(rawValue: $0.status) }
    }

    func isDateAvailableBySchedule(_ date: Date) -> Bool {
        guard isDateWithinBookingWindow(date) else { return false }

        switch availabilityStatus(for: date) {
        case .blocked, .hold, .booked:
            return false
        case nil:
            return draft.weeklySchedule.isAvailable(on: date)
        }
    }

    func isDateWithinBookingWindow(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let startDate = calendar.date(byAdding: .day, value: draft.leadTimeDays, to: calendar.startOfDay(for: .now)) ?? .now
        let endDate = calendar.date(byAdding: .day, value: draft.advanceBookingDays, to: calendar.startOfDay(for: .now)) ?? .now
        return normalizedDate >= startDate && normalizedDate <= endDate
    }

    func canEditAvailabilityOverride(on date: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: .now)
        guard normalizedDate >= today else { return false }
        if availabilityStatus(for: date) == .booked { return false }
        return true
    }

    func cycleAvailability(on date: Date) async {
        guard let vendorID = sessionStore.currentUserID else { return }
        guard canEditAvailabilityOverride(on: date) else { return }

        let normalizedDate = Calendar.current.startOfDay(for: date)

        // Guard against rapid double-taps
        guard !pendingOverrideDates.contains(normalizedDate) else { return }
        pendingOverrideDates.insert(normalizedDate)
        defer { pendingOverrideDates.remove(normalizedDate) }

        let currentStatus = availabilityStatus(for: normalizedDate)
        let nextStatus: VendorAvailabilityStatus?

        switch currentStatus {
        case nil:
            nextStatus = .blocked
        case .blocked:
            nextStatus = nil
        case .hold:
            nextStatus = nil
        case .booked:
            nextStatus = .booked
        }

        // Snapshot for rollback
        let previousRecords = availabilityRecords

        // Optimistic local update with animation
        withAnimation(.easeInOut(duration: 0.2)) {
            mutateAvailabilityLocally(date: normalizedDate, vendorID: vendorID, to: nextStatus)
        }

        do {
            if let nextStatus {
                try await availabilityService.setAvailability(
                    vendorID: vendorID,
                    date: normalizedDate,
                    status: nextStatus.rawValue
                )
            } else {
                try await availabilityService.removeAvailability(vendorID: vendorID, date: normalizedDate)
            }
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            // Rollback on failure
            availabilityRecords = previousRecords
            loadingState = .failed(error.localizedDescription)
        }
    }

    private func mutateAvailabilityLocally(date: Date, vendorID: UUID, to status: VendorAvailabilityStatus?) {
        availabilityRecords.removeAll { record in
            guard let recordDate = record.date else { return false }
            return Calendar.current.isDate(recordDate, inSameDayAs: date)
        }

        if let status {
            availabilityRecords.append(
                VendorAvailabilityRecord(
                    vendorID: vendorID,
                    date: date,
                    status: status.rawValue
                )
            )
        }
    }

    private func availabilityFetchEndDate() -> Date {
        Calendar.current.date(byAdding: .day, value: 365, to: .now) ?? .now
    }

    func ensureLeadIntakeQuestions() {
        if draft.leadIntakeQuestions.isEmpty {
            draft.leadIntakeQuestions = LeadIntakeTemplateLibrary.defaultQuestions(for: draft.category)
        }
    }

    func resetLeadIntakeQuestionsToTemplate() {
        draft.leadIntakeQuestions = LeadIntakeTemplateLibrary.defaultQuestions(for: draft.category)
    }

    func blockDates(_ dates: [Date]) async {
        guard let vendorID = sessionStore.currentUserID else { return }

        let calendar = Calendar.current
        let editableDates = dates
            .map { calendar.startOfDay(for: $0) }
            .filter { canEditAvailabilityOverride(on: $0) }

        guard !editableDates.isEmpty else { return }

        let previousRecords = availabilityRecords

        withAnimation(.easeInOut(duration: 0.2)) {
            for date in editableDates {
                mutateAvailabilityLocally(date: date, vendorID: vendorID, to: .blocked)
            }
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for date in editableDates {
                    group.addTask {
                        try await self.availabilityService.setAvailability(
                            vendorID: vendorID,
                            date: date,
                            status: VendorAvailabilityStatus.blocked.rawValue
                        )
                    }
                }
                try await group.waitForAll()
            }
            lastSaveOutcome = .saved
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            availabilityRecords = previousRecords
            lastSaveOutcome = .failed(error.localizedDescription)
        }
    }

    func unblockDates(_ dates: [Date]) async {
        guard let vendorID = sessionStore.currentUserID else { return }

        let calendar = Calendar.current
        let editableDates = dates
            .map { calendar.startOfDay(for: $0) }
            .filter { canEditAvailabilityOverride(on: $0) }

        guard !editableDates.isEmpty else { return }

        let previousRecords = availabilityRecords

        withAnimation(.easeInOut(duration: 0.2)) {
            for date in editableDates {
                mutateAvailabilityLocally(date: date, vendorID: vendorID, to: nil)
            }
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for date in editableDates {
                    group.addTask {
                        try await self.availabilityService.removeAvailability(
                            vendorID: vendorID,
                            date: date
                        )
                    }
                }
                try await group.waitForAll()
            }
            lastSaveOutcome = .saved
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            availabilityRecords = previousRecords
            lastSaveOutcome = .failed(error.localizedDescription)
        }
    }

    func blockTimeslot(on date: Date, slot: TimeslotOption) async {
        guard let vendorID = sessionStore.currentUserID else { return }
        let record = VendorTimeslotBookingRecord(
            vendorID: vendorID,
            date: date,
            startTime: slot.startTimeString,
            endTime: slot.endTimeString,
            status: "blocked"
        )

        timeslotBookings.append(record)

        do {
            try await availabilityService.setTimeslotBooking(record: record)
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            timeslotBookings.removeAll { $0.id == record.id }
            loadingState = .failed(error.localizedDescription)
        }
    }

    func unblockTimeslot(on date: Date, slot: TimeslotOption) async {
        guard let vendorID = sessionStore.currentUserID else { return }
        let startTimeString = slot.startTimeString

        let removed = timeslotBookings.filter { booking in
            guard let bookingDate = booking.date else { return false }
            return Calendar.current.isDate(bookingDate, inSameDayAs: date)
                && booking.startTime.hasPrefix(String(startTimeString.prefix(5)))
                && booking.status == "blocked"
        }
        timeslotBookings.removeAll { removed.contains($0) }

        do {
            try await availabilityService.removeTimeslotBooking(
                vendorID: vendorID,
                date: date,
                startTime: startTimeString
            )
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            timeslotBookings.append(contentsOf: removed)
            loadingState = .failed(error.localizedDescription)
        }
    }

    func deleteVendorListing() async -> DeletionResult? {
        loadingState = .loading

        do {
            let result = try await vendorProfileService.deleteVendorListing()

            hasLoaded = false
            draft = VendorProfileDraft()
            availabilityRecords = []
            loadingState = .idle

            if let existing = sessionStore.authenticatedProfile {
                sessionStore.applyAuthenticatedSession(
                    AuthenticatedUserProfile(
                        userID: existing.userID,
                        emailAddress: existing.emailAddress,
                        displayName: existing.displayName,
                        vendorDisplayName: nil
                    ),
                    preferredRole: .host
                )
            }

            AppLogger.app.notice("Vendor listing deleted. \(result.cancelledBookings) bookings cancelled.")
            return result
        } catch is CancellationError {
            return nil
        } catch {
            loadingState = .failed(error.localizedDescription)
            AppLogger.networking.error("Failed to delete vendor listing: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
