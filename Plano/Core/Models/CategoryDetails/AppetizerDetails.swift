import Foundation

struct AppetizerDetails: Codable, Hashable {
    var serviceStyle: String = ""
    var dietaryAccommodations: [String] = []
    var minimumHeadcount: Int? = nil

    var isEmpty: Bool {
        serviceStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && dietaryAccommodations.isEmpty
            && minimumHeadcount == nil
    }

    static let serviceStyleOptions = [
        "Passed",
        "Stationed",
        "Grazing table",
        "Tasting portions",
        "Family style",
    ]

    static let dietaryOptions = [
        "Vegetarian",
        "Vegan",
        "Gluten-free",
        "Nut-free",
        "Halal",
        "Kosher",
    ]
}
