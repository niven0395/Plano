import Foundation

struct CateringDetails: Codable, Hashable {
    var cuisineTypes: [String] = []
    var serviceStyles: [String] = []
    var dietaryAccommodations: [String] = []
    var menuSections: [MenuSection] = []
    var tastingAvailable: Bool = false
    var servingStaffIncluded: Bool = false
    var tablewareIncluded: Bool = false
    var minimumHeadcount: Int?
    var maximumHeadcount: Int?

    var isEmpty: Bool {
        cuisineTypes.isEmpty
            && serviceStyles.isEmpty
            && dietaryAccommodations.isEmpty
            && menuSections.isEmpty
            && !tastingAvailable
            && !servingStaffIncluded
            && !tablewareIncluded
            && minimumHeadcount == nil
            && maximumHeadcount == nil
    }

    static let cuisineOptions = [
        "Italian",
        "Mexican",
        "BBQ",
        "Asian Fusion",
        "Southern",
        "Mediterranean",
        "Indian",
        "Caribbean",
        "American",
        "French",
        "Middle Eastern",
    ]

    static let serviceStyleOptions = [
        "Buffet",
        "Plated",
        "Family style",
        "Food stations",
        "Food truck",
        "Cocktail style",
        "Drop-off",
    ]

    static let dietaryOptions = [
        "Vegan",
        "Vegetarian",
        "Gluten-free",
        "Halal",
        "Kosher",
        "Nut-free",
        "Dairy-free",
    ]
}

struct MenuSection: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String = ""
    var items: [MenuItem] = []
}

struct MenuItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String = ""
    var description: String?
    var priceCents: Int?
}
