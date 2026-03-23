import Foundation

struct RentalDetails: Codable, Hashable {
    var rentalCategories: [String] = []
    var deliveryPickupIncluded: Bool = false
    var setupIncluded: Bool = false

    var isEmpty: Bool {
        rentalCategories.isEmpty
            && !deliveryPickupIncluded
            && !setupIncluded
    }

    static let rentalCategoryOptions = [
        "Tables",
        "Chairs",
        "Tents",
        "Linens",
        "Lighting",
        "AV equipment",
        "Lounge furniture",
        "Dance floor",
        "Tableware",
    ]
}
