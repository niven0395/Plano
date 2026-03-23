import Foundation

struct PhotoboothDetails: Codable, Hashable {
    var boothTypes: [String] = []
    var propsIncluded: Bool = false
    var attendantIncluded: Bool = false

    var isEmpty: Bool {
        boothTypes.isEmpty
            && !propsIncluded
            && !attendantIncluded
    }

    static let boothTypeOptions = [
        "Open air",
        "Enclosed",
        "360 booth",
        "Mirror booth",
        "GIF booth",
        "Glam booth",
    ]
}
