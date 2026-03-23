import Foundation

nonisolated struct WeeklySchedule: Hashable, Codable {
    let preset: SchedulePreset
    let availableDays: Set<Weekday>

    init(preset: SchedulePreset, availableDays: Set<Weekday>) {
        self.preset = preset
        self.availableDays = preset.availableDays ?? availableDays
    }

    func isAvailable(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let weekday = Weekday(date: date, calendar: calendar) else {
            return false
        }

        return availableDays.contains(weekday)
    }

    func derivedAvailabilityMode(for bookingMode: BookingMode) -> AvailabilityMode {
        guard !availableDays.isEmpty else {
            return .contactToDiscuss
        }

        switch bookingMode {
        case .acceptOnline:
            return .showCalendar
        case .requestOnly, .inquiryOnly:
            return .manualReview
        }
    }

    static let everyDay = WeeklySchedule(
        preset: .everyDay,
        availableDays: Set(Weekday.allCases)
    )

    static func resolve(
        rawPreset: String?,
        availableDayValues: [Int]?,
        fallbackAvailabilityMode: AvailabilityMode?
    ) -> WeeklySchedule {
        let normalizedDays = Set((availableDayValues ?? []).compactMap(Weekday.init(rawValue:)))

        if let preset = rawPreset.flatMap(SchedulePreset.init(rawValue:)) {
            return WeeklySchedule(
                preset: preset,
                availableDays: normalizedDays
            )
        }

        if !normalizedDays.isEmpty {
            return WeeklySchedule(
                preset: SchedulePreset.matchingPreset(for: normalizedDays),
                availableDays: normalizedDays
            )
        }

        return legacyDefault(for: fallbackAvailabilityMode ?? .contactToDiscuss)
    }

    static func legacyDefault(for availabilityMode: AvailabilityMode) -> WeeklySchedule {
        switch availabilityMode {
        case .showCalendar, .manualReview:
            .everyDay
        case .contactToDiscuss:
            WeeklySchedule(preset: .custom, availableDays: [])
        }
    }
}
