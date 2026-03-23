import Foundation

nonisolated enum Weekday: Int, CaseIterable, Identifiable, Codable, Comparable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Self { self }

    var shortName: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let index = rawValue - 1

        guard symbols.indices.contains(index) else {
            return fallbackShortName
        }

        return symbols[index]
    }

    var fullName: String {
        let symbols = Calendar.current.weekdaySymbols
        let index = rawValue - 1

        guard symbols.indices.contains(index) else {
            return fallbackFullName
        }

        return symbols[index]
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init?(date: Date, calendar: Calendar = .current) {
        self.init(rawValue: calendar.component(.weekday, from: date))
    }

    private var fallbackShortName: String {
        switch self {
        case .sunday:
            "Sun"
        case .monday:
            "Mon"
        case .tuesday:
            "Tue"
        case .wednesday:
            "Wed"
        case .thursday:
            "Thu"
        case .friday:
            "Fri"
        case .saturday:
            "Sat"
        }
    }

    private var fallbackFullName: String {
        switch self {
        case .sunday:
            "Sunday"
        case .monday:
            "Monday"
        case .tuesday:
            "Tuesday"
        case .wednesday:
            "Wednesday"
        case .thursday:
            "Thursday"
        case .friday:
            "Friday"
        case .saturday:
            "Saturday"
        }
    }
}
