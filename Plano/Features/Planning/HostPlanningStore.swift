import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class HostPlanningStore {
    private static let selectedEventKey = "plano.host.selected-event-id"
    private static let savedVendorKey = "plano.host.saved-vendor-ids"
    private static let onboardingKey = "plano.host.did-complete-onboarding"
    private static let plannedVendorSelectionsKey = "plano.host.planned-vendor-selections"
    private static let additionalCategoriesKey = "plano.host.additional-categories"
    private static let removedRecommendedCategoriesKey = "plano.host.removed-recommended-categories"

    private struct PlannedVendorSelectionRecord: Codable {
        let eventID: UUID
        let category: VendorCategory
        let vendorID: UUID
    }

    private struct AdditionalCategoriesRecord: Codable {
        let eventID: UUID
        let categories: [VendorCategory]
    }

    private struct RemovedCategoriesRecord: Codable {
        let eventID: UUID
        let categories: [VendorCategory]
    }

    private let defaults: UserDefaults
    @ObservationIgnored private let eventService: any EventServiceProtocol
    @ObservationIgnored private let vendorSearchService: any VendorSearchServiceProtocol
    @ObservationIgnored private let plannedVendorService: any PlannedVendorServiceProtocol
    // Action items placeholder — populated when booking coordination is wired
    @ObservationIgnored private var hasLoadedEvents = false
    @ObservationIgnored private var pendingSavedVendorIDs: Set<UUID> = []

    var loadingState: LoadingState = .idle
    var events: [PartyEvent]
    var selectedEventID: UUID {
        didSet {
            defaults.set(selectedEventID.uuidString, forKey: Self.selectedEventKey)
        }
    }
    var savedVendorIDs: Set<UUID> {
        didSet {
            defaults.set(savedVendorIDs.map(\.uuidString), forKey: Self.savedVendorKey)
        }
    }
    var plannedVendorAssignments: [UUID: [VendorCategory: UUID]] {
        didSet {
            persistPlannedVendorAssignments()
        }
    }
    var additionalCategoriesByEventID: [UUID: [VendorCategory]] {
        didSet {
            persistAdditionalCategories()
        }
    }
    var removedRecommendedCategoriesByEventID: [UUID: [VendorCategory]] {
        didSet {
            persistRemovedRecommendedCategories()
        }
    }
    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Self.onboardingKey)
        }
    }
    var vendors: [VendorProfile]
    var recommendedVendors: [VendorProfile] = []

    init(
        eventService: any EventServiceProtocol,
        vendorSearchService: any VendorSearchServiceProtocol,
        plannedVendorService: any PlannedVendorServiceProtocol,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.eventService = eventService
        self.vendorSearchService = vendorSearchService
        self.plannedVendorService = plannedVendorService
        events = []
        vendors = []
        let storedSavedVendorIDs = (defaults.array(forKey: Self.savedVendorKey) as? [String] ?? [])
            .compactMap(UUID.init)
        savedVendorIDs = Set(storedSavedVendorIDs)
        plannedVendorAssignments = Self.decodePlannedVendorAssignments(
            from: defaults.data(forKey: Self.plannedVendorSelectionsKey)
        )
        additionalCategoriesByEventID = Self.decodeAdditionalCategories(
            from: defaults.data(forKey: Self.additionalCategoriesKey)
        )
        removedRecommendedCategoriesByEventID = Self.decodeRemovedRecommendedCategories(
            from: defaults.data(forKey: Self.removedRecommendedCategoriesKey)
        )

        hasCompletedOnboarding = defaults.object(forKey: Self.onboardingKey) as? Bool ?? false

        let storedEventID = defaults.string(forKey: Self.selectedEventKey).flatMap(UUID.init)
        selectedEventID = storedEventID ?? PartyEvent.placeholder.id
    }

    var selectedEvent: PartyEvent {
        events.first(where: { $0.id == selectedEventID }) ?? events.first ?? .placeholder
    }

    var currentActionItems: [BookingRequestSummary] {
        []
    }

    var metrics: [MetricSummary] {
        [
            MetricSummary(title: "Pending", value: "\(currentActionItems.count)", detail: "active vendor decisions", tone: .gold),
            MetricSummary(title: "Saved", value: "\(savedVendorIDs.count)", detail: "shortlisted vendors", tone: .blue),
            MetricSummary(title: "Events", value: "\(events.count)", detail: "active event plans", tone: .sage),
        ]
    }

    func selectEvent(_ eventID: UUID) {
        guard events.contains(where: { $0.id == eventID }) else { return }
        selectedEventID = eventID
        rebuildRecommendedVendorsFromCache()

        Task { [weak self] in
            await self?.refreshRecommendedVendors()
        }
    }

    @discardableResult
    func addEvent(from draft: EventDraft) async -> PartyEvent? {
        let optimisticEvent = draft.makeEvent()
        let previousEvents = events
        let previousSelectedEventID = selectedEventID
        let previousOnboardingState = hasCompletedOnboarding

        events.insert(optimisticEvent, at: 0)
        selectedEventID = optimisticEvent.id
        hasCompletedOnboarding = true
        loadingState = .loaded
        rebuildRecommendedVendorsFromCache()

        do {
            let persistedEvent = try await eventService.createEvent(from: draft)

            if let index = events.firstIndex(where: { $0.id == optimisticEvent.id }) {
                events[index] = persistedEvent
            } else {
                events.insert(persistedEvent, at: 0)
            }

            selectedEventID = persistedEvent.id
            hasLoadedEvents = true
            await refreshRecommendedVendors()
            return persistedEvent
        } catch {
            events = previousEvents
            selectedEventID = previousEvents.contains(where: { $0.id == previousSelectedEventID })
                ? previousSelectedEventID
                : previousEvents.first?.id ?? PartyEvent.placeholder.id
            hasCompletedOnboarding = previousOnboardingState
            loadingState = .failed(error.localizedDescription)
            rebuildRecommendedVendorsFromCache()
            AppLogger.networking.error("Failed to create event: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func loadIfNeeded() async {
        guard !hasLoadedEvents else { return }
        await load()
    }

    func load() async {
        loadingState = .loading

        do {
            let fetchedEvents = try await eventService.fetchEvents()
                .sorted(by: { $0.date < $1.date })

            events = fetchedEvents
            hasLoadedEvents = true
            hasCompletedOnboarding = !fetchedEvents.isEmpty

            if let selectedEvent = fetchedEvents.first(where: { $0.id == selectedEventID }) {
                selectedEventID = selectedEvent.id
            } else {
                selectedEventID = fetchedEvents.first?.id ?? PartyEvent.placeholder.id
            }

            await syncPlannedVendorsFromServer()
            await refreshSavedVendorsFromBackend()
            await refreshRecommendedVendors()
            loadingState = .loaded
        } catch {
            loadingState = .failed(error.localizedDescription)
            AppLogger.networking.error("Failed to load events: \(error.localizedDescription, privacy: .public)")
        }
    }

    func prepareForSignedOutState() {
        hasLoadedEvents = false
        pendingSavedVendorIDs = []
        loadingState = .idle
        events = []
        vendors = []
        recommendedVendors = []
        savedVendorIDs = []
        plannedVendorAssignments = [:]
        additionalCategoriesByEventID = [:]
        removedRecommendedCategoriesByEventID = [:]
        selectedEventID = PartyEvent.placeholder.id
        hasCompletedOnboarding = false
    }

    func filteredVendors(query: String, category: VendorCategory?) -> [VendorProfile] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase

        return vendors
            .filter { vendor in
                let matchesCategory = category.map { vendor.category == $0 } ?? true

                guard !trimmedQuery.isEmpty else {
                    return matchesCategory
                }

                let haystack = [
                    vendor.businessName,
                    vendor.displayCategoryTitle,
                    vendor.city,
                    vendor.serviceArea,
                    vendor.styleSummary,
                    vendor.badge,
                    vendor.intro,
                    vendor.tags.joined(separator: " "),
                ]
                .joined(separator: " ")
                .localizedLowercase

                return matchesCategory && haystack.contains(trimmedQuery)
            }
            .sorted(by: compareVendors)
    }

    func toggleSavedVendor(_ vendorID: UUID) {
        guard !pendingSavedVendorIDs.contains(vendorID) else { return }

        let shouldSave = !savedVendorIDs.contains(vendorID)
        let previousSavedVendorIDs = savedVendorIDs

        if shouldSave {
            savedVendorIDs.insert(vendorID)
        } else {
            savedVendorIDs.remove(vendorID)
        }

        pendingSavedVendorIDs.insert(vendorID)
        rebuildRecommendedVendorsFromCache()

        Task { [weak self] in
            await self?.persistSavedVendorChange(
                vendorID,
                shouldSave: shouldSave,
                previousSavedVendorIDs: previousSavedVendorIDs
            )
        }
    }

    func isSavedVendor(_ vendorID: UUID) -> Bool {
        savedVendorIDs.contains(vendorID)
    }

    func isSavedVendorSyncPending(_ vendorID: UUID) -> Bool {
        pendingSavedVendorIDs.contains(vendorID)
    }

    func vendor(id: UUID) -> VendorProfile? {
        vendors.first(where: { $0.id == id })
    }

    func event(id: UUID) -> PartyEvent? {
        events.first(where: { $0.id == id })
    }

    func plannedVendorID(for eventID: UUID, category: VendorCategory) -> UUID? {
        plannedVendorAssignments[eventID]?[category]
    }

    func plannedVendor(for eventID: UUID, category: VendorCategory) -> VendorProfile? {
        plannedVendorID(for: eventID, category: category).flatMap(vendor(id:))
    }

    func additionalCategories(for eventID: UUID) -> [VendorCategory] {
        additionalCategoriesByEventID[eventID] ?? []
    }

    func categories(for event: PartyEvent) -> [VendorCategory] {
        let removed = Set(removedRecommendedCategoriesByEventID[event.id] ?? [])
        let recommended = event.recommendedCategories.filter { !removed.contains($0) }
        let additional = additionalCategoriesByEventID[event.id] ?? []
        return recommended + additional.filter { !recommended.contains($0) }
    }

    func applyCategorySelection(_ selection: [VendorCategory], to event: PartyEvent) {
        let recommended = event.recommendedCategories
        let selected = Set(selection)
        let additional = selection.filter { !recommended.contains($0) }
        let removed = recommended.filter { !selected.contains($0) }

        if additional.isEmpty {
            additionalCategoriesByEventID.removeValue(forKey: event.id)
        } else {
            additionalCategoriesByEventID[event.id] = additional
        }

        if removed.isEmpty {
            removedRecommendedCategoriesByEventID.removeValue(forKey: event.id)
        } else {
            removedRecommendedCategoriesByEventID[event.id] = removed
        }
    }

    func addCategory(_ category: VendorCategory, to event: PartyEvent) {
        if event.recommendedCategories.contains(category) {
            var removed = removedRecommendedCategoriesByEventID[event.id] ?? []
            removed.removeAll { $0 == category }

            if removed.isEmpty {
                removedRecommendedCategoriesByEventID.removeValue(forKey: event.id)
            } else {
                removedRecommendedCategoriesByEventID[event.id] = removed
            }
        } else {
            addAdditionalCategory(category, to: event.id)
        }
    }

    func planVendor(_ vendorID: UUID, for category: VendorCategory, eventID: UUID) {
        guard vendors.contains(where: { $0.id == vendorID }) else { return }

        let previousAssignments = plannedVendorAssignments

        var assignments = plannedVendorAssignments[eventID] ?? [:]
        assignments[category] = vendorID
        plannedVendorAssignments[eventID] = assignments

        if let event = event(id: eventID) {
            addCategory(category, to: event)
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await plannedVendorService.planVendor(
                    eventID: eventID,
                    vendorID: vendorID,
                    category: category
                )
            } catch {
                plannedVendorAssignments = previousAssignments
                AppLogger.networking.error("Failed to persist planned vendor \(vendorID.uuidString, privacy: .public) to server: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func clearPlannedVendor(for category: VendorCategory, eventID: UUID) {
        guard var assignments = plannedVendorAssignments[eventID] else { return }

        let vendorID = assignments[category]
        let previousAssignments = plannedVendorAssignments

        assignments.removeValue(forKey: category)

        if assignments.isEmpty {
            plannedVendorAssignments.removeValue(forKey: eventID)
        } else {
            plannedVendorAssignments[eventID] = assignments
        }

        guard let vendorID else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await plannedVendorService.removePlannedVendor(
                    eventID: eventID,
                    vendorID: vendorID
                )
            } catch {
                plannedVendorAssignments = previousAssignments
                AppLogger.networking.error("Failed to remove planned vendor \(vendorID.uuidString, privacy: .public) from server: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func addAdditionalCategory(_ category: VendorCategory, to eventID: UUID) {
        var categories = additionalCategoriesByEventID[eventID] ?? []
        guard !categories.contains(category) else { return }
        categories.append(category)
        additionalCategoriesByEventID[eventID] = categories
    }

    func removeAdditionalCategory(_ category: VendorCategory, from eventID: UUID) {
        var categories = additionalCategoriesByEventID[eventID] ?? []
        categories.removeAll { $0 == category }

        if categories.isEmpty {
            additionalCategoriesByEventID.removeValue(forKey: eventID)
        } else {
            additionalCategoriesByEventID[eventID] = categories
        }

        clearPlannedVendor(for: category, eventID: eventID)
    }

    @discardableResult
    func updateVenue(_ venue: String, for eventID: UUID) async -> PartyEvent? {
        guard let existingEvent = event(id: eventID) else { return nil }

        let normalizedVenue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousEvents = events

        if let index = events.firstIndex(where: { $0.id == eventID }) {
            events[index].venue = normalizedVenue
        }

        do {
            let updatedEvent = try await eventService.updateEventVenue(normalizedVenue, eventID: eventID)

            if let index = events.firstIndex(where: { $0.id == updatedEvent.id }) {
                events[index] = updatedEvent
            } else {
                events.append(updatedEvent)
                events.sort { $0.date < $1.date }
            }

            return updatedEvent
        } catch {
            events = previousEvents
            AppLogger.networking.error("Failed to update event venue for \(existingEvent.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @discardableResult
    func deleteEvent(_ eventID: UUID) async -> DeletionResult? {
        guard let target = event(id: eventID) else { return nil }

        let previousEvents = events
        let previousSelectedEventID = selectedEventID

        events.removeAll { $0.id == eventID }
        plannedVendorAssignments.removeValue(forKey: eventID)
        additionalCategoriesByEventID.removeValue(forKey: eventID)
        removedRecommendedCategoriesByEventID.removeValue(forKey: eventID)

        if selectedEventID == eventID {
            selectedEventID = events.first?.id ?? PartyEvent.placeholder.id
        }

        hasCompletedOnboarding = !events.isEmpty
        rebuildRecommendedVendorsFromCache()

        do {
            let result = try await eventService.deleteEvent(eventID: eventID)
            AppLogger.app.notice("Deleted event '\(target.title, privacy: .public)'. \(result.cancelledBookings) bookings cancelled.")
            return result
        } catch {
            events = previousEvents
            selectedEventID = previousSelectedEventID
            hasCompletedOnboarding = !events.isEmpty
            rebuildRecommendedVendorsFromCache()
            AppLogger.networking.error("Failed to delete event \(eventID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func sortDiscoveryVendors(_ vendors: [VendorProfile], preferredCity: String?) -> [VendorProfile] {
        let normalizedPreferredCity = preferredCity?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedLowercase

        return vendors.sorted { lhs, rhs in
            let lhsMatchesCity = lhs.city.localizedLowercase == normalizedPreferredCity
            let rhsMatchesCity = rhs.city.localizedLowercase == normalizedPreferredCity

            if lhsMatchesCity != rhsMatchesCity {
                return lhsMatchesCity && !rhsMatchesCity
            }

            return compareVendors(lhs: lhs, rhs: rhs)
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func replayOnboarding() {
        hasCompletedOnboarding = false
    }

    func searchVendors(matching request: VendorSearchRequest) async throws -> [VendorProfile] {
        let records = try await vendorSearchService.searchVendors(matching: request)
        let mappedVendors = makeVendorProfiles(from: records)
        cacheDiscoveryVendors(mappedVendors)
        rebuildRecommendedVendorsFromCache()
        return mappedVendors
    }

    func syncPlannedVendorsFromServer() async {
        let eventIDs = events.map(\.id)
        guard !eventIDs.isEmpty else { return }

        do {
            let records = try await plannedVendorService.fetchAllPlannedVendors(eventIDs: eventIDs)

            var serverAssignments: [UUID: [VendorCategory: UUID]] = [:]
            for record in records where record.plannedVendorStatus != .removed {
                serverAssignments[record.eventID, default: [:]][record.vendorCategory] = record.vendorID
            }

            plannedVendorAssignments = serverAssignments
        } catch {
            AppLogger.networking.error("Failed to sync planned vendors from server: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Callers must reload `InboxStore` conversations after this returns with
    /// `successCount > 0`, since this function bypasses InboxStore for
    /// conversation creation and booking submission.
    func sendBookingRequests(
        eventID: UUID,
        bookingService: any BookingServiceProtocol,
        hostID: UUID,
        note: String = ""
    ) async -> SendRequestsResult {
        guard let event = event(id: eventID) else {
            return SendRequestsResult(successCount: 0, failedVendorIDs: [], createdConversationIDs: [])
        }

        let assignments = plannedVendorAssignments[eventID] ?? [:]
        guard !assignments.isEmpty else {
            return SendRequestsResult(successCount: 0, failedVendorIDs: [], createdConversationIDs: [])
        }

        var successCount = 0
        var failedVendorIDs: [UUID] = []
        var createdConversationIDs: [UUID] = []

        let resolvedNote: String = {
            if !note.isEmpty { return note }
            if !event.planningNote.isEmpty { return event.planningNote }
            return "Booking request for \(event.title)"
        }()

        for (category, vendorID) in assignments {
            if vendorID == hostID {
                failedVendorIDs.append(vendorID)
                AppLogger.networking.warning("Skipped self-messaging for vendor \(vendorID.uuidString, privacy: .public) in batch send")
                continue
            }

            do {
                let conversation = try await bookingService.createConversation(
                    vendorID: vendorID,
                    hostID: hostID,
                    eventID: eventID
                )
                createdConversationIDs.append(conversation.id)

                _ = try await bookingService.submitBookingRequest(
                    conversationID: conversation.id,
                    eventDate: event.date,
                    note: resolvedNote
                )

                try await plannedVendorService.updateStatus(
                    eventID: eventID,
                    vendorID: vendorID,
                    status: .requestSent
                )

                successCount += 1
            } catch {
                failedVendorIDs.append(vendorID)
                AppLogger.networking.error("Failed to send booking request for vendor \(vendorID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return SendRequestsResult(
            successCount: successCount,
            failedVendorIDs: failedVendorIDs,
            createdConversationIDs: createdConversationIDs
        )
    }

    func rebuildRecommendedVendorsFromCache() {
        recommendedVendors = Array(
            vendors
                .sorted(by: compareVendors)
                .prefix(12)
        )
    }

    func cacheDiscoveryVendors(_ incomingVendors: [VendorProfile]) {
        guard !incomingVendors.isEmpty else { return }

        var mergedVendorsByID = Dictionary(uniqueKeysWithValues: vendors.map { ($0.id, $0) })
        for vendor in incomingVendors {
            mergedVendorsByID[vendor.id] = vendor
        }

        vendors = Array(mergedVendorsByID.values)
    }

    private func compareVendors(lhs: VendorProfile, rhs: VendorProfile) -> Bool {
        let lhsScore = rankingScore(for: lhs)
        let rhsScore = rankingScore(for: rhs)

        if lhsScore != rhsScore {
            return lhsScore > rhsScore
        }

        if lhs.ratingValue != rhs.ratingValue {
            return lhs.ratingValue > rhs.ratingValue
        }

        return lhs.businessName < rhs.businessName
    }

    private func rankingScore(for vendor: VendorProfile) -> Int {
        var score = 0

        if savedVendorIDs.contains(vendor.id) {
            score += 100
        }

        if categories(for: selectedEvent).contains(vendor.category) {
            score += 45
        }

        switch vendor.availability {
        case .available:
            score += 18
        case .bookingFast:
            score += 12
        case .limited:
            score += 8
        }

        score += Int(vendor.ratingValue * 10)
        score += min(vendor.reviewCount, 99) / 10
        score += max(50 - vendor.responseMinutes, 0)
        score += vendor.profileCompleteness / 3
        score += vendor.searchMomentumScore / 4

        return score
    }

    private func refreshSavedVendorsFromBackend() async {
        do {
            let backendSavedVendorIDs = try await vendorSearchService.fetchSavedVendorIDs()
            savedVendorIDs = backendSavedVendorIDs
        } catch {
            AppLogger.networking.error("Failed to load saved vendors: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshRecommendedVendors() async {
        do {
            let foundVendors = try await searchVendors(
                matching: VendorSearchRequest(
                    text: "",
                    category: nil,
                    limit: 36
                )
            )

            recommendedVendors = Array(foundVendors.sorted(by: compareVendors).prefix(12))
        } catch {
            rebuildRecommendedVendorsFromCache()
            AppLogger.search.error("Failed to refresh recommended vendors: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistPlannedVendorAssignments() {
        let records = plannedVendorAssignments.flatMap { eventID, assignments in
            assignments.map { category, vendorID in
                PlannedVendorSelectionRecord(eventID: eventID, category: category, vendorID: vendorID)
            }
        }

        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.plannedVendorSelectionsKey)
        }
    }

    private func persistAdditionalCategories() {
        let records = additionalCategoriesByEventID.map { eventID, categories in
            AdditionalCategoriesRecord(eventID: eventID, categories: categories)
        }

        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.additionalCategoriesKey)
        }
    }

    private func persistRemovedRecommendedCategories() {
        let records = removedRecommendedCategoriesByEventID.map { eventID, categories in
            RemovedCategoriesRecord(eventID: eventID, categories: categories)
        }

        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.removedRecommendedCategoriesKey)
        }
    }

    private static func decodePlannedVendorAssignments(from data: Data?) -> [UUID: [VendorCategory: UUID]] {
        guard let data,
              let records = try? JSONDecoder().decode([PlannedVendorSelectionRecord].self, from: data) else {
            return [:]
        }

        return records.reduce(into: [UUID: [VendorCategory: UUID]]()) { partialResult, record in
            partialResult[record.eventID, default: [:]][record.category] = record.vendorID
        }
    }

    private static func decodeAdditionalCategories(from data: Data?) -> [UUID: [VendorCategory]] {
        guard let data,
              let records = try? JSONDecoder().decode([AdditionalCategoriesRecord].self, from: data) else {
            return [:]
        }

        return records.reduce(into: [UUID: [VendorCategory]]()) { partialResult, record in
            partialResult[record.eventID] = record.categories
        }
    }

    private static func decodeRemovedRecommendedCategories(from data: Data?) -> [UUID: [VendorCategory]] {
        guard let data,
              let records = try? JSONDecoder().decode([RemovedCategoriesRecord].self, from: data) else {
            return [:]
        }

        return records.reduce(into: [UUID: [VendorCategory]]()) { partialResult, record in
            partialResult[record.eventID] = record.categories
        }
    }

    private func persistSavedVendorChange(
        _ vendorID: UUID,
        shouldSave: Bool,
        previousSavedVendorIDs: Set<UUID>
    ) async {
        do {
            if shouldSave {
                try await vendorSearchService.saveVendor(vendorID)
            } else {
                try await vendorSearchService.unsaveVendor(vendorID)
            }
        } catch {
            savedVendorIDs = previousSavedVendorIDs
            rebuildRecommendedVendorsFromCache()
            AppLogger.search.error("Failed to sync saved vendor \(vendorID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        pendingSavedVendorIDs.remove(vendorID)
    }

    // MARK: - Vendor Profile Mapping

    private func makeVendorProfiles(from records: [VendorProfileRecord]) -> [VendorProfile] {
        records.map { record in
            let fallback = vendor(id: record.userID)

            return record.makeVendorProfile(
                fallbackCategory: fallback?.category ?? .entertainer,
                responseTime: fallback?.responseTime ?? "Responds in 1h",
                ratingValue: fallback?.ratingValue ?? 4.8,
                reviewCount: fallback?.reviewCount ?? 0,
                badge: fallback?.badge ?? "Fresh profile",
                intro: fallback?.intro ?? record.bio,
                availability: fallback?.availability ?? .bookingFast,
                services: record.services ?? fallback?.services ?? [],
                packages: fallback?.packages ?? [],
                galleryImages: fallback?.galleryImages ?? [],
                review: fallback?.review ?? VendorReviewSnippet(
                    author: "Recent host",
                    eventTypeLabel: "Private event",
                    quote: "Clear communication and a straightforward public profile."
                ),
                reviewHighlights: fallback?.reviewHighlights ?? [],
                availabilitySummary: fallback?.availabilitySummary ?? VendorAvailabilitySummary(
                    nextOpeningLabel: "Availability on request",
                    leadTimeLabel: "Lead time varies",
                    eventDateSupportLabel: "The vendor reviews dates directly once you reach out.",
                    supportsSelectedEventDate: true,
                    windows: []
                ),
                repeatBookingRateLabel: fallback?.repeatBookingRateLabel ?? "New listing",
                searchMomentumScore: fallback?.searchMomentumScore ?? 72
            )
        }
    }
}

struct SendRequestsResult {
    let successCount: Int
    let failedVendorIDs: [UUID]
    let createdConversationIDs: [UUID]
}
