import Foundation

struct HairStylistDetails: Codable, Hashable {
    var serviceTypes: [String] = []
    var travelToVenue: Bool = false
    var trialIncluded: Bool = false
    var groupRatesAvailable: Bool = false

    var isEmpty: Bool {
        serviceTypes.isEmpty
            && !travelToVenue
            && !trialIncluded
            && !groupRatesAvailable
    }

    static let serviceTypeOptions = [
        "Updos",
        "Blowouts",
        "Braiding",
        "Extensions",
        "Coloring",
        "Cuts",
        "Styling",
    ]
}
