import Foundation

enum EventType: String, CaseIterable, Identifiable, Codable {
    case engagement
    case birthday
    case bridalShower
    case babyShower
    case cocktailNight
    case dinnerParty
    case wedding
    case corporate
    case anniversary
    case graduation

    var id: Self { self }

    var title: String {
        switch self {
        case .engagement:
            "Engagement Party"
        case .birthday:
            "Birthday Celebration"
        case .bridalShower:
            "Bridal Shower"
        case .babyShower:
            "Baby Shower"
        case .cocktailNight:
            "Cocktail Night"
        case .dinnerParty:
            "Dinner Party"
        case .wedding:
            "Wedding"
        case .corporate:
            "Corporate Event"
        case .anniversary:
            "Anniversary"
        case .graduation:
            "Graduation Party"
        }
    }

    var subtitle: String {
        switch self {
        case .engagement:
            "Intimate editorial dinner energy with polished details."
        case .birthday:
            "Lively room, clear entertainment, confident visual moments."
        case .bridalShower:
            "Soft hospitality, photography, florals, and hosting flow."
        case .babyShower:
            "Warm daytime energy with styling and guest comfort first."
        case .cocktailNight:
            "Fast-moving hospitality with strong music and room rhythm."
        case .dinnerParty:
            "Focused tablescape, food quality, and calm host control."
        case .wedding:
            "High-trust production across ceremony, dinner, and celebration."
        case .corporate:
            "Clear timing, polished hospitality, and operational reliability."
        case .anniversary:
            "Warm celebration energy with hospitality and photo moments first."
        case .graduation:
            "Flexible celebration planning with strong food, music, and coverage."
        }
    }

    var searchPromptTitle: String {
        switch self {
        case .engagement:
            "Engagement"
        case .birthday:
            "Birthday"
        case .bridalShower:
            "Bridal shower"
        case .babyShower:
            "Baby shower"
        case .cocktailNight:
            "Cocktail"
        case .dinnerParty:
            "Dinner party"
        case .wedding:
            "Wedding"
        case .corporate:
            "Corporate"
        case .anniversary:
            "Anniversary"
        case .graduation:
            "Graduation"
        }
    }

    var recommendedCategories: [VendorCategory] {
        switch self {
        case .engagement:
            [.eventSpace, .decorator, .photographer, .caterer, .florist, .dj]
        case .birthday:
            [.eventSpace, .dj, .decorator, .caterer, .photographer, .baker, .photobooth]
        case .bridalShower:
            [.eventSpace, .decorator, .photographer, .florist, .caterer, .baker]
        case .babyShower:
            [.eventSpace, .decorator, .caterer, .photographer, .baker]
        case .cocktailNight:
            [.eventSpace, .bartender, .dj, .photographer, .caterer, .decorator, .photobooth]
        case .dinnerParty:
            [.eventSpace, .caterer, .decorator, .bartender, .photographer, .florist]
        case .wedding:
            [.eventSpace, .photographer, .caterer, .dj, .florist, .baker, .makeupArtist, .rental, .photobooth]
        case .corporate:
            [.eventSpace, .caterer, .photographer, .entertainer, .rental]
        case .anniversary:
            [.eventSpace, .photographer, .caterer, .decorator, .florist, .baker]
        case .graduation:
            [.eventSpace, .caterer, .photographer, .dj, .baker, .decorator, .photobooth]
        }
    }
}

enum GuestCountTier: String, CaseIterable, Identifiable, Codable {
    case intimate
    case medium
    case large
    case fullScale

    var id: Self { self }

    var title: String {
        switch self {
        case .intimate:
            "Intimate"
        case .medium:
            "Medium"
        case .large:
            "Large"
        case .fullScale:
            "Full scale"
        }
    }

    var label: String {
        switch self {
        case .intimate:
            "18-35 guests"
        case .medium:
            "35-60 guests"
        case .large:
            "60-120 guests"
        case .fullScale:
            "120+ guests"
        }
    }

    var representativeCount: Int {
        switch self {
        case .intimate:
            25
        case .medium:
            50
        case .large:
            90
        case .fullScale:
            140
        }
    }
}

enum GuestCountValue {
    static let defaultCount = GuestCountTier.medium.representativeCount

    static func label(for guestCount: Int) -> String {
        guard guestCount > 0 else {
            return "Guest count pending"
        }

        let formattedCount = guestCount.formatted()
        return guestCount == 1 ? "\(formattedCount) guest" : "\(formattedCount) guests"
    }

    static func resolve(from storedValue: String) -> Int {
        let trimmedValue = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let directCount = Int(trimmedValue), directCount > 0 {
            return directCount
        }

        if let legacyTier = GuestCountTier(rawValue: trimmedValue) {
            return legacyTier.representativeCount
        }

        let extractedNumbers = trimmedValue
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init)

        switch extractedNumbers.count {
        case let count where count >= 2:
            return max((extractedNumbers[0] + extractedNumbers[1]) / 2, 1)
        case 1:
            return max(extractedNumbers[0], 1)
        default:
            return defaultCount
        }
    }
}

enum VenueSetting: String, CaseIterable, Identifiable, Codable {
    case indoor
    case outdoor
    case both
    case tbd

    var id: Self { self }

    var title: String {
        switch self {
        case .indoor: "Indoor"
        case .outdoor: "Outdoor"
        case .both: "Indoor & Outdoor"
        case .tbd: "TBD"
        }
    }
}

enum EventDuration {
    static func hours(from start: Date, to end: Date) -> Double {
        var interval = end.timeIntervalSince(start)
        if interval <= 0 {
            interval += 24 * 3600
        }
        return interval / 3600
    }

    static func label(hours: Double) -> String {
        let wholeHours = Int(hours)
        let remainingMinutes = Int((hours - Double(wholeHours)) * 60)

        if remainingMinutes == 0 {
            return wholeHours == 1 ? "1 hour" : "\(wholeHours) hours"
        }
        return "\(wholeHours)h \(remainingMinutes)m"
    }

    static func shortLabel(hours: Double) -> String {
        let wholeHours = Int(hours)
        let remainingMinutes = Int((hours - Double(wholeHours)) * 60)

        if remainingMinutes == 0 {
            return wholeHours == 1 ? "1 hr" : "\(wholeHours) hrs"
        }
        return "\(wholeHours)h \(remainingMinutes)m"
    }
}

struct EventSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let kind: String
    let dateLabel: String
    let venue: String
    let guestCountLabel: String
    let venueSettingLabel: String
    let timeRangeLabel: String
    let durationLabel: String?
    let completionText: String
    let progress: Double
    let stage: BookingStage
    let eventStage: EventStage

    init(
        id: UUID = UUID(),
        title: String,
        kind: String,
        dateLabel: String,
        venue: String,
        guestCountLabel: String,
        venueSettingLabel: String = VenueSetting.tbd.title,
        timeRangeLabel: String = "Times TBD",
        durationLabel: String? = nil,
        completionText: String,
        progress: Double,
        stage: BookingStage,
        eventStage: EventStage = .planning
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.dateLabel = dateLabel
        self.venue = venue
        self.guestCountLabel = guestCountLabel
        self.venueSettingLabel = venueSettingLabel
        self.timeRangeLabel = timeRangeLabel
        self.durationLabel = durationLabel
        self.completionText = completionText
        self.progress = progress
        self.stage = stage
        self.eventStage = eventStage
    }
}

struct PartyEvent: Identifiable, Hashable {
    let id: UUID
    var title: String
    var type: EventType
    var date: Date
    var venue: String
    var city: String
    var guestCount: Int
    var budgetLabel: String?
    var startTime: Date?
    var endTime: Date?
    var durationHours: Double?
    var venueSetting: VenueSetting
    var planningNote: String
    var progress: Double
    var stage: BookingStage
    var eventStage: EventStage

    var recommendedCategories: [VendorCategory] {
        type.recommendedCategories
    }

    var summary: EventSummary {
        EventSummary(
            id: id,
            title: title,
            kind: type.title,
            dateLabel: formattedDate,
            venue: venue,
            guestCountLabel: guestCountLabel,
            venueSettingLabel: venueSetting.title,
            timeRangeLabel: timeRangeLabel,
            durationLabel: durationLabel,
            completionText: planningNote,
            progress: progress,
            stage: stage,
            eventStage: eventStage
        )
    }

    var guestCountLabel: String {
        GuestCountValue.label(for: guestCount)
    }

    var formattedDate: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var contextLine: String {
        "\(city) · \(venueSetting.title) · \(guestCountLabel)"
    }

    var timeRangeLabel: String {
        guard let start = startTime, let end = endTime else {
            return "Times TBD"
        }
        let timeFormat = Date.FormatStyle.dateTime.hour().minute()
        let durationSuffix = if let durationHours {
            " (\(EventDuration.shortLabel(hours: durationHours)))"
        } else {
            ""
        }
        return "\(start.formatted(timeFormat)) – \(end.formatted(timeFormat))\(durationSuffix)"
    }

    var durationLabel: String? {
        guard let durationHours else { return nil }
        return EventDuration.label(hours: durationHours)
    }

    var formattedDateWithTime: String {
        if startTime != nil {
            "\(formattedDate) · \(timeRangeLabel)"
        } else {
            formattedDate
        }
    }

    static let placeholder = PartyEvent(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000E001") ?? UUID(),
        title: "New Event",
        type: .engagement,
        date: Calendar.current.date(byAdding: .day, value: 21, to: .now) ?? .now,
        venue: "Add a venue",
        city: GTACity.toronto.rawValue,
        guestCount: GuestCountValue.defaultCount,
        venueSetting: .tbd,
        planningNote: "Create your first event to unlock discovery and workspace context.",
        progress: 0,
        stage: .requested,
        eventStage: .planning
    )
}

struct EventDraft: Hashable {
    var title = ""
    var type: EventType = .engagement
    var date = Calendar.current.date(byAdding: .day, value: 21, to: .now) ?? .now
    var venue = ""
    var city = GTACity.toronto.rawValue
    var guestCount: Int = GuestCountValue.defaultCount
    var startTime: Date?
    var endTime: Date?
    var venueSetting: VenueSetting = .tbd
    var planningNote = ""

    var guestCountLabel: String {
        GuestCountValue.label(for: guestCount)
    }

    var computedDurationHours: Double? {
        guard let start = startTime, let end = endTime else { return nil }
        return EventDuration.hours(from: start, to: end)
    }

    var isValid: Bool {
        let hasCity = !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasGuests = guestCount > 0
        let timeValid = startTime == nil || endTime != nil
        return hasCity && hasGuests && timeValid
    }

    func makeEvent(id: UUID = UUID()) -> PartyEvent {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedVenue = venue.trimmingCharacters(in: .whitespacesAndNewlines)

        return PartyEvent(
            id: id,
            title: normalizedTitle.isEmpty ? type.title : normalizedTitle,
            type: type,
            date: date,
            venue: normalizedVenue.isEmpty ? "Venue TBD" : normalizedVenue,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            guestCount: guestCount,
            startTime: startTime,
            endTime: endTime,
            durationHours: computedDurationHours,
            venueSetting: venueSetting,
            planningNote: planningNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Fresh event brief. Start search with the key vendor categories."
                : planningNote.trimmingCharacters(in: .whitespacesAndNewlines),
            progress: 0.12,
            stage: .requested,
            eventStage: .planning
        )
    }
}
