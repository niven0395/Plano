import Foundation

struct EntertainerDetails: Codable, Hashable {
    var entertainmentType: String = ""
    var suitableAgeRange: String = ""
    var isInteractive: Bool = false

    var isEmpty: Bool {
        entertainmentType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && suitableAgeRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isInteractive
    }
}
