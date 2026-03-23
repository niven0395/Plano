import Foundation

nonisolated enum SchedulePreset: String, CaseIterable, Identifiable, Codable {
    case everyDay = "every_day"
    case weekdaysOnly = "weekdays_only"
    case weekendsOnly = "weekends_only"
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .everyDay:
            "Every day"
        case .weekdaysOnly:
            "Weekdays"
        case .weekendsOnly:
            "Weekends"
        case .custom:
            "Custom"
        }
    }

    var availableDays: Set<Weekday>? {
        switch self {
        case .everyDay:
            Set(Weekday.allCases)
        case .weekdaysOnly:
            [.monday, .tuesday, .wednesday, .thursday, .friday]
        case .weekendsOnly:
            [.sunday, .saturday]
        case .custom:
            nil
        }
    }

    static func matchingPreset(for availableDays: Set<Weekday>) -> SchedulePreset {
        if availableDays == Set(Weekday.allCases) {
            return .everyDay
        }

        if let weekdays = SchedulePreset.weekdaysOnly.availableDays,
           availableDays == weekdays {
            return .weekdaysOnly
        }

        if let weekends = SchedulePreset.weekendsOnly.availableDays,
           availableDays == weekends {
            return .weekendsOnly
        }

        return .custom
    }
}
