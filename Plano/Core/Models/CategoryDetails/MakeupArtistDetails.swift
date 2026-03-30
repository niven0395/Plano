import Foundation

struct MakeupArtistDetails: Codable, Hashable {
    var specialties: [String] = []
    var travelToVenue: Bool = false
    var trialIncluded: Bool = false
    var hairServicesAvailable: Bool = false
    var groupRatesAvailable: Bool = false

    var isEmpty: Bool {
        specialties.isEmpty
            && !travelToVenue
            && !trialIncluded
            && !hairServicesAvailable
            && !groupRatesAvailable
    }

    static let specialtyOptions = [
        "Bridal",
        "Natural / no-makeup look",
        "Editorial",
        "SFX",
        "Airbrush",
        "South Asian",
        "Dark skin tones",
    ]
}
