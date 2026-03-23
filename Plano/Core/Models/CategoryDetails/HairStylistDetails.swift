import Foundation

struct HairStylistDetails: Codable, Hashable {
    var travelToVenue: Bool = false
    var trialIncluded: Bool = false
    var groupRatesAvailable: Bool = false

    var isEmpty: Bool {
        !travelToVenue
            && !trialIncluded
            && !groupRatesAvailable
    }
}
