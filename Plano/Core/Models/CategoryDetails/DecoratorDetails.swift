import Foundation

struct DecoratorDetails: Codable, Hashable {
    var serviceTypes: [String] = []
    var setupTeardownIncluded: Bool = false
    var materialsProvided: Bool = false

    var isEmpty: Bool {
        serviceTypes.isEmpty
            && !setupTeardownIncluded
            && !materialsProvided
    }

    static let serviceTypeOptions = [
        "Full venue styling",
        "Table settings",
        "Backdrops",
        "Entrance decor",
        "Ceiling decor",
        "Signage",
    ]
}
