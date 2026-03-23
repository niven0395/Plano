import Foundation

nonisolated enum PriceTier: String, CaseIterable, Identifiable, Codable, Comparable {
    case starter
    case professional
    case elite

    var id: Self { self }

    var title: String {
        switch self {
        case .starter:
            "Starter"
        case .professional:
            "Professional"
        case .elite:
            "Elite"
        }
    }

    var signal: String {
        switch self {
        case .starter:
            "Entry-level value"
        case .professional:
            "Established mid-range"
        case .elite:
            "Premium sought-after"
        }
    }

    static func < (lhs: PriceTier, rhs: PriceTier) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    private var sortIndex: Int {
        switch self {
        case .starter:
            0
        case .professional:
            1
        case .elite:
            2
        }
    }
}

nonisolated enum PricingModel: String, CaseIterable, Identifiable, Codable {
    case startingFrom = "starting_from"
    case perEvent = "per_event"
    case perHour = "per_hour"
    case perPerson = "per_person"
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .startingFrom:
            "Starting from"
        case .perEvent:
            "Per event"
        case .perHour:
            "Per hour"
        case .perPerson:
            "Per person"
        case .custom:
            "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .startingFrom:
            "Set a minimum entry point for your work."
        case .perEvent:
            "Quote a flat fee for a typical event."
        case .perHour:
            "Charge by the hour with an optional minimum."
        case .perPerson:
            "Price against guest count with a minimum."
        case .custom:
            "List individual services and their prices."
        }
    }

    var symbolName: String {
        switch self {
        case .startingFrom:
            "arrow.up.forward.square"
        case .perEvent:
            "calendar"
        case .perHour:
            "clock"
        case .perPerson:
            "person.2"
        case .custom:
            "list.bullet.rectangle"
        }
    }
}

nonisolated enum PricingAmountFormatter {
    static func currencyLabel(forCents cents: Int) -> String {
        let dollars = max(Int((Double(cents) / 100).rounded()), 0)
        return "$\(dollars.formatted())"
    }
}

nonisolated enum PricingVisibility: String, CaseIterable, Identifiable, Codable {
    case `public`
    case onRequest = "on_request"
    case hidden

    var id: Self { self }

    var title: String {
        switch self {
        case .public:
            "Show pricing"
        case .onRequest:
            "On request"
        case .hidden:
            "Hide pricing"
        }
    }
}
