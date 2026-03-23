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
        case .photobooth: nil
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

    func priceRange(for tier: PriceTier) -> (low: Int, high: Int?) {
        switch self {
        case .decorator:
            switch tier {
            case .starter: (500, 2_000)
            case .professional: (2_000, 6_000)
            case .elite: (6_000, nil)
            }
        case .photographer:
            switch tier {
            case .starter: (300, 1_500)
            case .professional: (1_500, 4_000)
            case .elite: (4_000, nil)
            }
        case .dj:
            switch tier {
            case .starter: (200, 600)
            case .professional: (600, 2_000)
            case .elite: (2_000, nil)
            }
        case .caterer:
            switch tier {
            case .starter: (800, 2_500)
            case .professional: (2_500, 7_000)
            case .elite: (7_000, nil)
            }
        case .eventSpace:
            switch tier {
            case .starter: (1_000, 4_000)
            case .professional: (4_000, 12_000)
            case .elite: (12_000, nil)
            }
        case .baker:
            switch tier {
            case .starter: (150, 450)
            case .professional: (450, 1_200)
            case .elite: (1_200, nil)
            }
        case .florist:
            switch tier {
            case .starter: (400, 1_200)
            case .professional: (1_200, 3_500)
            case .elite: (3_500, nil)
            }
        case .entertainer:
            switch tier {
            case .starter: (250, 800)
            case .professional: (800, 2_500)
            case .elite: (2_500, nil)
            }
        case .rental:
            switch tier {
            case .starter: (300, 1_200)
            case .professional: (1_200, 4_000)
            case .elite: (4_000, nil)
            }
        case .bartender:
            switch tier {
            case .starter: (250, 700)
            case .professional: (700, 1_800)
            case .elite: (1_800, nil)
            }
        case .makeupArtist:
            switch tier {
            case .starter: (200, 500)
            case .professional: (500, 1_500)
            case .elite: (1_500, nil)
            }
        case .experienceStation:
            switch tier {
            case .starter: (300, 900)
            case .professional: (900, 2_500)
            case .elite: (2_500, nil)
            }
        case .appetizer:
            switch tier {
            case .starter: (400, 1_200)
            case .professional: (1_200, 3_500)
            case .elite: (3_500, nil)
            }
        case .hairStylist:
            switch tier {
            case .starter: (150, 400)
            case .professional: (400, 1_200)
            case .elite: (1_200, nil)
            }
        case .studio:
            switch tier {
            case .starter: (200, 700)
            case .professional: (700, 2_000)
            case .elite: (2_000, nil)
            }
        case .desserts:
            switch tier {
            case .starter: (300, 900)
            case .professional: (900, 2_500)
            case .elite: (2_500, nil)
            }
        case .photobooth:
            switch tier {
            case .starter: (300, 900)
            case .professional: (900, 2_500)
            case .elite: (2_500, nil)
            }
        }
    }

    func priceRangeLabel(for tier: PriceTier) -> String {
        let range = priceRange(for: tier)
        let low = Self.formattedPriceAmount(range.low)

        if let high = range.high {
            return "\(low) - \(Self.formattedPriceAmount(high))"
        }

        return "\(low)+"
    }

    func priceTier(for basePriceCents: Int) -> PriceTier {
        let normalizedPrice = max(basePriceCents / 100, 0)

        if normalizedPrice < priceRange(for: .professional).low {
            return .starter
        }

        if normalizedPrice < priceRange(for: .elite).low {
            return .professional
        }

        return .elite
    }

    private static func formattedPriceAmount(_ amount: Int) -> String {
        "$\(amount.formatted())"
    }
}
