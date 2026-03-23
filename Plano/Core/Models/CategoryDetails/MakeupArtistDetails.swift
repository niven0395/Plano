import Foundation

struct MakeupArtistDetails: Codable, Hashable {
    var travelToVenue: Bool = false
    var trialIncluded: Bool = false
    var hairServicesAvailable: Bool = false
    var groupRatesAvailable: Bool = false

    var isEmpty: Bool {
        !travelToVenue
            && !trialIncluded
            && !hairServicesAvailable
            && !groupRatesAvailable
    }
}
