import Foundation

enum AvailabilitySignal: String, Codable {
    case available
    case bookingFast
    case limited

    var title: String {
        switch self {
        case .available:
            "Open dates"
        case .bookingFast:
            "Booking fast"
        case .limited:
            "Limited openings"
        }
    }

    var detail: String {
        switch self {
        case .available:
            "Strong fit for near-term dates."
        case .bookingFast:
            "Good option, but holds may move quickly."
        case .limited:
            "Only a few viable windows remain."
        }
    }

    var tone: AccentTone {
        switch self {
        case .available:
            .sage
        case .bookingFast:
            .gold
        case .limited:
            .coral
        }
    }
}

enum VendorAvailabilityStatus: String, CaseIterable, Identifiable, Codable {
    case booked
    case blocked
    case hold

    var id: Self { self }

    var title: String {
        switch self {
        case .booked:
            "Booked"
        case .blocked:
            "Blocked"
        case .hold:
            "Hold"
        }
    }
}

nonisolated enum AvailabilityWindowState: String, Codable {
    case open
    case limited
    case booked

    var title: String {
        switch self {
        case .open:
            "Open"
        case .limited:
            "Limited"
        case .booked:
            "Booked"
        }
    }

    var tone: AccentTone {
        switch self {
        case .open:
            .sage
        case .limited:
            .gold
        case .booked:
            .coral
        }
    }
}

nonisolated struct AvailabilityWindow: Identifiable, Hashable {
    let id: UUID
    let label: String
    let state: AvailabilityWindowState

    init(id: UUID = UUID(), label: String, state: AvailabilityWindowState) {
        self.id = id
        self.label = label
        self.state = state
    }
}

nonisolated struct VendorAvailabilitySummary: Hashable {
    let nextOpeningLabel: String
    let leadTimeLabel: String
    let eventDateSupportLabel: String
    let supportsSelectedEventDate: Bool
    let windows: [AvailabilityWindow]
}

nonisolated struct VendorSummary: Identifiable, Hashable {
    let id: UUID
    let businessName: String
    let category: VendorCategory
    let city: String
    let startingPrice: String
    let responseTime: String
    let ratingText: String
    let highlight: String
    let badge: String

    init(
        id: UUID = UUID(),
        businessName: String,
        category: VendorCategory,
        city: String,
        startingPrice: String,
        responseTime: String,
        ratingText: String,
        highlight: String,
        badge: String
    ) {
        self.id = id
        self.businessName = businessName
        self.category = category
        self.city = city
        self.startingPrice = startingPrice
        self.responseTime = responseTime
        self.ratingText = ratingText
        self.highlight = highlight
        self.badge = badge
    }
}

nonisolated struct VendorPackage: Identifiable, Hashable {
    let id: UUID
    let title: String
    let priceLabel: String
    let summary: String
    let tier: PriceTier?
    let includedItems: [String]

    init(
        id: UUID = UUID(),
        title: String,
        priceLabel: String,
        summary: String,
        tier: PriceTier? = nil,
        includedItems: [String] = []
    ) {
        self.id = id
        self.title = title
        self.priceLabel = priceLabel
        self.summary = summary
        self.tier = tier
        self.includedItems = includedItems
    }
}

nonisolated struct VendorServiceItem: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var priceCents: Int
    var description: String
    var displayOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        priceCents: Int,
        description: String = "",
        displayOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.priceCents = priceCents
        self.description = description
        self.displayOrder = displayOrder
    }

    var priceLabel: String {
        PricingAmountFormatter.currencyLabel(forCents: priceCents)
    }
}

nonisolated struct VendorReviewSnippet: Hashable {
    let author: String
    let eventTypeLabel: String
    let quote: String
}

nonisolated struct VendorGalleryImage: Identifiable, Hashable, Codable {
    let id: UUID
    let storagePath: String
    let displayOrder: Int
    let caption: String

    init(
        id: UUID = UUID(),
        storagePath: String,
        displayOrder: Int,
        caption: String = ""
    ) {
        self.id = id
        self.storagePath = storagePath
        self.displayOrder = displayOrder
        self.caption = caption
    }
}

nonisolated struct VendorReviewEntry: Identifiable, Hashable {
    let id: UUID
    let author: String
    let eventTypeLabel: String
    let timelineLabel: String
    let rating: Int
    let quote: String

    init(
        id: UUID = UUID(),
        author: String,
        eventTypeLabel: String,
        timelineLabel: String,
        rating: Int,
        quote: String
    ) {
        self.id = id
        self.author = author
        self.eventTypeLabel = eventTypeLabel
        self.timelineLabel = timelineLabel
        self.rating = rating
        self.quote = quote
    }
}

nonisolated struct VendorPolicy: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var body: String

    init(id: UUID = UUID(), title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

struct VendorSocialLink: Identifiable, Hashable {
    enum Kind: Hashable {
        case instagram
        case website
        case phone
        case tiktok

        var symbolName: String {
            switch self {
            case .instagram:
                "camera.circle.fill"
            case .website:
                "globe"
            case .phone:
                "phone.fill"
            case .tiktok:
                "music.note.tv.fill"
            }
        }

        var title: String {
            switch self {
            case .instagram:
                "Instagram"
            case .website:
                "Website"
            case .phone:
                "Phone"
            case .tiktok:
                "TikTok"
            }
        }
    }

    let kind: Kind
    let value: String

    var id: String { "\(kind.title)-\(value)" }

    var label: String {
        switch kind {
        case .instagram:
            value.hasPrefix("@") ? value : "@\(value)"
        case .website, .phone, .tiktok:
            value
        }
    }
}
