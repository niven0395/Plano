import Foundation

enum UserRole: String, CaseIterable, Identifiable, Codable {
    case host
    case vendor

    var id: Self { self }

    var title: String {
        switch self {
        case .host:
            "Host"
        case .vendor:
            "Vendor"
        }
    }

    var subtitle: String {
        switch self {
        case .host:
            "Curate every vendor touchpoint with calm, clear decisions."
        case .vendor:
            "Keep leads moving and event days sharp."
        }
    }

    var counterpart: UserRole {
        switch self {
        case .host:
            .vendor
        case .vendor:
            .host
        }
    }
}
