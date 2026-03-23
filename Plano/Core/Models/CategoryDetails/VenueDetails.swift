import Foundation

struct VenueDetails: Codable, Hashable {
    var seatedCapacity: Int?
    var standingCapacity: Int?
    var venueStyle: String = ""
    var eventTypes: [String] = []
    var includedAmenities: [String] = []
    var parkingNote: String = ""
    var alcoholPolicy: String = ""
    var cateringPolicy: String = ""
    var bartenderIncluded: Bool = false
    var noiseRestriction: String = ""
    var setupTeardownIncluded: Bool = false

    var isEmpty: Bool {
        seatedCapacity == nil
            && standingCapacity == nil
            && venueStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && eventTypes.isEmpty
            && includedAmenities.isEmpty
            && parkingNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && alcoholPolicy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && cateringPolicy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !bartenderIncluded
            && noiseRestriction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !setupTeardownIncluded
    }

    static let venueStyleOptions = [
        "Indoor",
        "Outdoor",
        "Indoor & outdoor",
    ]

    static let eventTypeOptions = [
        "Weddings",
        "Corporate",
        "Birthdays",
        "Baby showers",
        "Private parties",
        "All events",
    ]

    static let amenityOptions = [
        "Chairs",
        "Tables",
        "Sound system",
        "Projector",
        "Wi-Fi",
        "Kitchen",
        "Restrooms",
        "Parking",
        "Decorations",
        "Stage",
        "Dance floor",
        "Lighting",
        "Heating/AC",
        "Bridal suite",
    ]

    static let alcoholPolicyOptions = [
        "BYOB",
        "Licensed bar on-site",
        "No alcohol",
        "Vendor provides",
    ]

    static let cateringPolicyOptions = [
        "In-house catering only",
        "Approved vendors list",
        "Any outside vendor",
        "No catering facilities",
    ]
}
