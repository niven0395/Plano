import Foundation

struct CategoryBrowseFilterState {
    var selectedCity: String?
    var ratingFilter: SearchRatingFilter = .all
    var sortMode: SearchSortMode = .recommended
    var availabilityDate: Date?

    var selectedMultiChoice: [String: Set<String>] = [:]
    var selectedToggles: [String: Bool] = [:]
    var guestCount: Int?

    var hasActiveFilters: Bool {
        selectedCity != nil
            || ratingFilter != .all
            || sortMode != .recommended
            || availabilityDate != nil
            || !selectedMultiChoice.values.allSatisfy(\.isEmpty)
            || selectedToggles.values.contains(true)
            || guestCount != nil
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedCity != nil { count += 1 }
        if ratingFilter != .all { count += 1 }
        if sortMode != .recommended { count += 1 }
        if availabilityDate != nil { count += 1 }
        count += selectedMultiChoice.values.filter { !$0.isEmpty }.count
        count += selectedToggles.values.filter { $0 }.count
        if guestCount != nil { count += 1 }
        return count
    }

    mutating func reset() {
        selectedCity = nil
        ratingFilter = .all
        sortMode = .recommended
        availabilityDate = nil
        selectedMultiChoice = [:]
        selectedToggles = [:]
        guestCount = nil
    }

    // MARK: - Multi-Choice Helpers

    func selectedValues(for key: String) -> Set<String> {
        selectedMultiChoice[key] ?? []
    }

    mutating func toggleMultiChoice(key: String, value: String) {
        var current = selectedMultiChoice[key] ?? []
        if current.contains(value) {
            current.remove(value)
        } else {
            current.insert(value)
        }
        selectedMultiChoice[key] = current
    }

    func isToggleOn(_ key: String) -> Bool {
        selectedToggles[key] ?? false
    }

    mutating func setToggle(_ key: String, value: Bool) {
        selectedToggles[key] = value ? true : nil
    }

    // MARK: - Category-Specific Matching

    func matchesCategoryFilters(_ vendor: VendorProfile, category: VendorCategory) -> Bool {
        guard let details = vendor.categoryDetails else { return true }

        switch (category, details) {
        case (.eventSpace, .venue(let d)):
            return matchesVenue(d)
        case (.caterer, .catering(let d)):
            return matchesCatering(d)
        case (.photographer, .photoVideo(let d)):
            return matchesPhotoVideo(d)
        case (.dj, .dj(let d)):
            return matchesDJ(d)
        case (.baker, .baker(let d)):
            return matchesBaker(d)
        case (.florist, .florist(let d)):
            return matchesFlorist(d)
        case (.decorator, .decorator(let d)):
            return matchesDecorator(d)
        case (.bartender, .bartender(let d)):
            return matchesBartender(d)
        case (.makeupArtist, .makeupArtist(let d)):
            return matchesMakeupArtist(d)
        case (.entertainer, .entertainer(let d)):
            return matchesEntertainer(d)
        default:
            return true
        }
    }

    // MARK: - Per-Category Match Logic

    private func matchesVenue(_ d: VenueDetails) -> Bool {
        if let guestCount, let seated = d.seatedCapacity, seated < guestCount {
            return false
        }
        if !matchesMultiChoice("venueStyle", vendorValues: d.venueStyle.isEmpty ? [] : [d.venueStyle]) { return false }
        return true
    }

    private func matchesCatering(_ d: CateringDetails) -> Bool {
        if !matchesMultiChoice("cuisineTypes", vendorValues: d.cuisineTypes) { return false }
        if !matchesMultiChoice("dietaryAccommodations", vendorValues: d.dietaryAccommodations) { return false }
        if isToggleOn("delivery") && !d.serviceStyles.contains("Drop-off") { return false }
        return true
    }

    private func matchesPhotoVideo(_ d: PhotoVideoDetails) -> Bool {
        if isToggleOn("droneAvailable") && !d.droneAvailable { return false }
        return true
    }

    private func matchesDJ(_ d: DJDetails) -> Bool {
        if !matchesMultiChoice("musicGenres", vendorValues: d.musicGenres) { return false }
        return true
    }

    private func matchesBaker(_ d: BakerDetails) -> Bool {
        if !matchesMultiChoice("specialties", vendorValues: d.specialties) { return false }
        if isToggleOn("delivery") && !d.deliveryAvailable { return false }
        return true
    }

    private func matchesFlorist(_ d: FloristDetails) -> Bool {
        if isToggleOn("deliverySetup") && !d.deliverySetupIncluded { return false }
        return true
    }

    private func matchesDecorator(_ d: DecoratorDetails) -> Bool {
        return true
    }

    private func matchesBartender(_ d: BartenderDetails) -> Bool {
        if !matchesMultiChoice("barTypes", vendorValues: d.barTypes) { return false }
        return true
    }

    private func matchesMakeupArtist(_ d: MakeupArtistDetails) -> Bool {
        if isToggleOn("travelToVenue") && !d.travelToVenue { return false }
        return true
    }

    private func matchesEntertainer(_ d: EntertainerDetails) -> Bool {
        return true
    }

    // MARK: - Shared Match Helper

    private func matchesMultiChoice(_ key: String, vendorValues: [String]) -> Bool {
        let selected = selectedValues(for: key)
        guard !selected.isEmpty else { return true }
        return !selected.isDisjoint(with: vendorValues)
    }
}
