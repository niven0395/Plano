import Foundation

struct StudioDetails: Codable, Hashable {
    var studioType: String = ""
    var equipmentIncluded: Bool = false
    var maxOccupancy: Int? = nil

    var isEmpty: Bool {
        studioType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !equipmentIncluded
            && maxOccupancy == nil
    }

    static let studioTypeOptions = [
        "Photography",
        "Video",
        "Podcast",
        "Music",
        "Dance",
        "Multi-purpose",
    ]
}
