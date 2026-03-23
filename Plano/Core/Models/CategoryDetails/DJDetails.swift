import Foundation

struct DJDetails: Codable, Hashable {
    var musicGenres: [String] = []
    var mcServicesAvailable: Bool = false
    var lightingPackageAvailable: Bool = false

    var isEmpty: Bool {
        musicGenres.isEmpty
            && !mcServicesAvailable
            && !lightingPackageAvailable
    }

    static let genreOptions = [
        "Pop",
        "Hip Hop",
        "R&B",
        "Latin",
        "EDM",
        "Rock",
        "Country",
        "Afrobeats",
        "Reggaeton",
        "Jazz",
        "Oldies",
    ]
}
