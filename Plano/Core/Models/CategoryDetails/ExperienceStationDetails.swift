import Foundation

struct ExperienceStationDetails: Codable, Hashable {
    var stationType: String = ""
    var setupIncluded: Bool = false
    var equipmentProvided: Bool = false

    var isEmpty: Bool {
        stationType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !setupIncluded
            && !equipmentProvided
    }

    static let stationTypeOptions = [
        "Photo station",
        "DIY craft",
        "Food station",
        "Game station",
        "Interactive display",
    ]
}
