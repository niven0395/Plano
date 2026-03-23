import Foundation

struct DessertsDetails: Codable, Hashable {
    var specialties: [String] = []
    var dietaryAccommodations: [String] = []
    var servesMinimumHeadcount: Int? = nil

    var isEmpty: Bool {
        specialties.isEmpty
            && dietaryAccommodations.isEmpty
            && servesMinimumHeadcount == nil
    }

    static let specialtyOptions = [
        "Cupcakes",
        "Pastries",
        "Chocolate",
        "Ice cream",
        "Macarons",
        "Fruit displays",
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
