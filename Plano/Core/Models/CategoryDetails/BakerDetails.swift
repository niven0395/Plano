import Foundation

struct BakerDetails: Codable, Hashable {
    var specialties: [String] = []
    var dietaryOptions: [String] = []
    var tastingAvailable: Bool = false
    var deliveryAvailable: Bool = false

    var isEmpty: Bool {
        specialties.isEmpty
            && dietaryOptions.isEmpty
            && !tastingAvailable
            && !deliveryAvailable
    }

    static let specialtyOptions = [
        "Custom cakes",
        "Cupcakes",
        "Cookies",
        "Pastries",
        "Macarons",
        "Donuts",
        "Cake pops",
    ]

    static let availableDietaryOptions = [
        "Vegan",
        "Gluten-free",
        "Nut-free",
        "Sugar-free",
        "Dairy-free",
    ]
}
