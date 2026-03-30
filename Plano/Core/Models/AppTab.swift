import Foundation

enum AppTab: Hashable {
    case home
    case search
    case inbox
    case events
    case profile
}

enum InboxFilter: String, CaseIterable, Identifiable {
    case all
    case unread
    case archived

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            "All"
        case .unread:
            "Unread"
        case .archived:
            "Archived"
        }
    }
}

struct MetricSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let value: String
    let detail: String
    let tone: AccentTone

    init(id: UUID = UUID(), title: String, value: String, detail: String, tone: AccentTone) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
        self.tone = tone
    }
}

struct ProfileQuickLink: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let symbolName: String

    init(id: UUID = UUID(), title: String, subtitle: String, symbolName: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
    }
}
