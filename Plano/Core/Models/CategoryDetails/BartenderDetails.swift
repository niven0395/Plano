import Foundation

struct BartenderDetails: Codable, Hashable {
    var barTypes: [String] = []
    var signatureCocktails: Bool = false
    var equipmentProvided: Bool = false
    var ingredientsIncluded: Bool = false

    var isEmpty: Bool {
        barTypes.isEmpty
            && !signatureCocktails
            && !equipmentProvided
            && !ingredientsIncluded
    }

    static let barTypeOptions = [
        "Full bar",
        "Beer & wine",
        "Cocktails only",
        "Mocktails",
        "Specialty cocktails",
    ]
}
