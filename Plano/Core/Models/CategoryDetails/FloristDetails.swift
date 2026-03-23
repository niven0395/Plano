import Foundation

struct FloristDetails: Codable, Hashable {
    var serviceTypes: [String] = []
    var deliverySetupIncluded: Bool = false
    var consultationIncluded: Bool = false

    var isEmpty: Bool {
        serviceTypes.isEmpty
            && !deliverySetupIncluded
            && !consultationIncluded
    }

    static let serviceTypeOptions = [
        "Bouquets",
        "Centerpieces",
        "Installations",
        "Corsages",
        "Boutonnieres",
        "Arches",
        "Ceremony decor",
    ]
}
