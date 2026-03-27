import Foundation

enum AccentTone: String, Hashable, Codable {
    case blue
    case sand
    case coral
    case sage
    case gold
}

nonisolated enum VendorCategory: String, CaseIterable, Identifiable, Codable {
    case decorator
    case photographer
    case dj
    case caterer
    case eventSpace
    case baker
    case florist
    case entertainer
    case rental
    case bartender
    case makeupArtist
    case experienceStation
    case appetizer
    case hairStylist
    case studio
    case desserts
    case photobooth

    // MARK: - Codable (backwards compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "venue":
            self = .eventSpace
        case "candyBuffet":
            self = .desserts
        case "stationer", "other":
            self = .entertainer
        default:
            guard let value = VendorCategory(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown vendor category: \(rawValue)"
                )
            }
            self = value
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .eventSpace:
            try container.encode("venue")
        default:
            try container.encode(rawValue)
        }
    }

    // MARK: - Home Display Order

    static let homeDisplayOrder: [VendorCategory] = [
        .eventSpace, .caterer, .appetizer, .decorator, .photographer, .studio,
        .experienceStation, .rental, .dj,
        .baker, .bartender, .florist, .entertainer,
        .makeupArtist, .hairStylist, .desserts,
        .photobooth,
    ]

    var id: Self { self }

    var title: String {
        switch self {
        case .decorator:
            "Decor"
        case .photographer:
            "Photo & Video"
        case .dj:
            "Music"
        case .caterer:
            "Catering"
        case .eventSpace:
            "Event spaces"
        case .baker:
            "Cakes"
        case .florist:
            "Florists"
        case .entertainer:
            "Entertainment"
        case .rental:
            "Rentals"
        case .bartender:
            "Bartenders"
        case .makeupArtist:
            "Makeup"
        case .experienceStation:
            "Experience stations"
        case .appetizer:
            "Apps"
        case .hairStylist:
            "Stylists"
        case .studio:
            "Studios"
        case .desserts:
            "Desserts"
        case .photobooth:
            "Photobooths"
        }
    }

    var singularTitle: String {
        switch self {
        case .decorator:
            "Decor"
        case .photographer:
            "Photo & Video"
        case .dj:
            "Music"
        case .caterer:
            "Catering"
        case .eventSpace:
            "Event space"
        case .baker:
            "Cakes"
        case .florist:
            "Florist"
        case .entertainer:
            "Entertainment"
        case .rental:
            "Rentals"
        case .bartender:
            "Bartender"
        case .makeupArtist:
            "Makeup"
        case .experienceStation:
            "Experience station"
        case .appetizer:
            "Apps"
        case .hairStylist:
            "Stylist"
        case .studio:
            "Studio"
        case .desserts:
            "Desserts"
        case .photobooth:
            "Photobooth"
        }
    }

    var symbolName: String {
        switch self {
        case .decorator:
            "sparkles"
        case .photographer:
            "camera.fill"
        case .dj:
            "music.note.list"
        case .caterer:
            "fork.knife"
        case .eventSpace:
            "building.columns.fill"
        case .baker:
            "birthday.cake.fill"
        case .florist:
            "leaf.fill"
        case .entertainer:
            "theatermasks.fill"
        case .rental:
            "chair.lounge.fill"
        case .bartender:
            "wineglass.fill"
        case .makeupArtist:
            "wand.and.stars"
        case .experienceStation:
            "cup.and.heat.waves.fill"
        case .appetizer:
            "carrot.fill"
        case .hairStylist:
            "scissors"
        case .studio:
            "photo.on.rectangle.angled"
        case .desserts:
            "cup.and.saucer.fill"
        case .photobooth:
            "camera.metering.spot"
        }
    }

    var accentTone: AccentTone {
        switch self {
        case .decorator, .florist:
            .coral
        case .photographer, .studio:
            .blue
        case .dj, .entertainer, .photobooth:
            .gold
        case .caterer, .bartender, .baker, .experienceStation, .appetizer, .desserts:
            .sage
        case .eventSpace, .rental, .makeupArtist, .hairStylist:
            .sand
        }
    }

    var categoryImageName: String? {
        switch self {
        case .eventSpace: "EventSpace"
        case .caterer: "Caterer"
        case .appetizer: "Appitizer"
        case .decorator: "Decorator"
        case .photographer: "Photographer"
        case .studio: "Studio"
        case .experienceStation: "Experience Station"
        case .rental: "Rentals"
        case .dj: "DJ"
        case .baker: "Cakes"
        case .bartender: "Bartender"
        case .florist: "Florist"
        case .entertainer: "Entertainer"
        case .makeupArtist: "Makeup"
        case .hairStylist: "Stylist"
        case .desserts: "Desserts"
        case .photobooth: "Photobooth"
        }
    }

    var searchKeywords: [String] {
        switch self {
        case .decorator:
            ["decor", "decorator", "styling", "design"]
        case .photographer:
            ["photography", "photographer", "photo", "camera", "videographer", "video", "film"]
        case .dj:
            ["dj", "music", "dance", "playlist"]
        case .caterer:
            ["caterer", "catering", "food", "menu"]
        case .eventSpace:
            ["venue", "space", "hall", "location", "event space"]
        case .baker:
            ["baker", "cake", "dessert", "pastry"]
        case .florist:
            ["florist", "flowers", "floral", "bouquets"]
        case .entertainer:
            ["entertainer", "performer", "show", "acts"]
        case .rental:
            ["rentals", "rental", "tables", "chairs"]
        case .bartender:
            ["bartender", "bar", "cocktails", "drinks"]
        case .makeupArtist:
            ["makeup", "makeup artist", "beauty", "glam"]
        case .experienceStation:
            ["experience", "station", "interactive", "activity", "DIY"]
        case .appetizer:
            ["appetizer", "hors d'oeuvres", "canapés", "finger food"]
        case .hairStylist:
            ["stylist", "hair", "hairdresser", "saree", "tailoring", "custom clothing"]
        case .studio:
            ["studio", "rental studio", "photo studio", "creative space"]
        case .desserts:
            ["dessert", "sweets", "pastry", "dessert table", "dessert catering"]
        case .photobooth:
            ["photobooth", "photo booth", "360 booth", "selfie station", "mirror booth", "open air booth"]
        }
    }

}
