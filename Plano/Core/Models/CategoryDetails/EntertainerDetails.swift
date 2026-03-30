import Foundation

struct EntertainerDetails: Codable, Hashable {
    var entertainmentTypes: [String] = []
    var entertainmentType: String = ""
    var suitableAgeRange: String = ""
    var isInteractive: Bool = false

    var isEmpty: Bool {
        entertainmentTypes.isEmpty
            && entertainmentType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && suitableAgeRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isInteractive
    }

    static let entertainmentTypeOptions = [
        "Live band",
        "Solo musician",
        "Magician",
        "Comedian",
        "Face painter",
        "Balloon artist",
        "Caricaturist",
        "Character performer",
    ]
}
