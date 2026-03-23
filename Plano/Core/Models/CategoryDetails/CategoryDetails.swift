import Foundation

enum CategoryDetails: Codable, Hashable {
    case photoVideo(PhotoVideoDetails)
    case catering(CateringDetails)
    case venue(VenueDetails)
    case dj(DJDetails)
    case baker(BakerDetails)
    case florist(FloristDetails)
    case decorator(DecoratorDetails)
    case entertainer(EntertainerDetails)
    case rental(RentalDetails)
    case bartender(BartenderDetails)
    case makeupArtist(MakeupArtistDetails)
    case experienceStation(ExperienceStationDetails)
    case appetizer(AppetizerDetails)
    case hairStylist(HairStylistDetails)
    case studio(StudioDetails)
    case desserts(DessertsDetails)
    case photobooth(PhotoboothDetails)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum CategoryType: String, Codable {
        case photoVideo
        case photography // backward compat
        case catering
        case venue
        case dj
        case baker
        case florist
        case decorator
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CategoryType.self, forKey: .type)

        let singleContainer = try decoder.singleValueContainer()

        switch type {
        case .photoVideo, .photography:
            self = .photoVideo(try singleContainer.decode(PhotoVideoDetails.self))
        case .catering:
            self = .catering(try singleContainer.decode(CateringDetails.self))
        case .venue:
            self = .venue(try singleContainer.decode(VenueDetails.self))
        case .dj:
            self = .dj(try singleContainer.decode(DJDetails.self))
        case .baker:
            self = .baker(try singleContainer.decode(BakerDetails.self))
        case .florist:
            self = .florist(try singleContainer.decode(FloristDetails.self))
        case .decorator:
            self = .decorator(try singleContainer.decode(DecoratorDetails.self))
        case .entertainer:
            self = .entertainer(try singleContainer.decode(EntertainerDetails.self))
        case .rental:
            self = .rental(try singleContainer.decode(RentalDetails.self))
        case .bartender:
            self = .bartender(try singleContainer.decode(BartenderDetails.self))
        case .makeupArtist:
            self = .makeupArtist(try singleContainer.decode(MakeupArtistDetails.self))
        case .experienceStation:
            self = .experienceStation(try singleContainer.decode(ExperienceStationDetails.self))
        case .appetizer:
            self = .appetizer(try singleContainer.decode(AppetizerDetails.self))
        case .hairStylist:
            self = .hairStylist(try singleContainer.decode(HairStylistDetails.self))
        case .studio:
            self = .studio(try singleContainer.decode(StudioDetails.self))
        case .desserts:
            self = .desserts(try singleContainer.decode(DessertsDetails.self))
        case .photobooth:
            self = .photobooth(try singleContainer.decode(PhotoboothDetails.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .photoVideo(let details):
            try container.encode(CategoryType.photoVideo, forKey: .type)
            try details.encode(to: encoder)
        case .catering(let details):
            try container.encode(CategoryType.catering, forKey: .type)
            try details.encode(to: encoder)
        case .venue(let details):
            try container.encode(CategoryType.venue, forKey: .type)
            try details.encode(to: encoder)
        case .dj(let details):
            try container.encode(CategoryType.dj, forKey: .type)
            try details.encode(to: encoder)
        case .baker(let details):
            try container.encode(CategoryType.baker, forKey: .type)
            try details.encode(to: encoder)
        case .florist(let details):
            try container.encode(CategoryType.florist, forKey: .type)
            try details.encode(to: encoder)
        case .decorator(let details):
            try container.encode(CategoryType.decorator, forKey: .type)
            try details.encode(to: encoder)
        case .entertainer(let details):
            try container.encode(CategoryType.entertainer, forKey: .type)
            try details.encode(to: encoder)
        case .rental(let details):
            try container.encode(CategoryType.rental, forKey: .type)
            try details.encode(to: encoder)
        case .bartender(let details):
            try container.encode(CategoryType.bartender, forKey: .type)
            try details.encode(to: encoder)
        case .makeupArtist(let details):
            try container.encode(CategoryType.makeupArtist, forKey: .type)
            try details.encode(to: encoder)
        case .experienceStation(let details):
            try container.encode(CategoryType.experienceStation, forKey: .type)
            try details.encode(to: encoder)
        case .appetizer(let details):
            try container.encode(CategoryType.appetizer, forKey: .type)
            try details.encode(to: encoder)
        case .hairStylist(let details):
            try container.encode(CategoryType.hairStylist, forKey: .type)
            try details.encode(to: encoder)
        case .studio(let details):
            try container.encode(CategoryType.studio, forKey: .type)
            try details.encode(to: encoder)
        case .desserts(let details):
            try container.encode(CategoryType.desserts, forKey: .type)
            try details.encode(to: encoder)
        case .photobooth(let details):
            try container.encode(CategoryType.photobooth, forKey: .type)
            try details.encode(to: encoder)
        }
    }

    // MARK: - isEmpty

    var isEmpty: Bool {
        switch self {
        case .photoVideo(let details): details.isEmpty
        case .catering(let details): details.isEmpty
        case .venue(let details): details.isEmpty
        case .dj(let details): details.isEmpty
        case .baker(let details): details.isEmpty
        case .florist(let details): details.isEmpty
        case .decorator(let details): details.isEmpty
        case .entertainer(let details): details.isEmpty
        case .rental(let details): details.isEmpty
        case .bartender(let details): details.isEmpty
        case .makeupArtist(let details): details.isEmpty
        case .experienceStation(let details): details.isEmpty
        case .appetizer(let details): details.isEmpty
        case .hairStylist(let details): details.isEmpty
        case .studio(let details): details.isEmpty
        case .desserts(let details): details.isEmpty
        case .photobooth(let details): details.isEmpty
        }
    }

    // MARK: - Section Title

    var sectionTitle: String {
        switch self {
        case .photoVideo: "Coverage & deliverables"
        case .catering: "Menu & service"
        case .venue: "Venue details"
        case .dj: "Sound & vibe"
        case .baker: "Cakes & flavors"
        case .florist: "Floral services"
        case .decorator: "What's included"
        case .entertainer: "Entertainment"
        case .rental: "What's available"
        case .bartender: "Bar service"
        case .makeupArtist: "Beauty services"
        case .experienceStation: "Experience setup"
        case .appetizer: "Appetizer service"
        case .hairStylist: "Styling services"
        case .studio: "Studio details"
        case .desserts: "Dessert menu"
        case .photobooth: "Booth setup"
        }
    }

    // MARK: - Factory

    static func empty(for category: VendorCategory) -> CategoryDetails {
        switch category {
        case .photographer: .photoVideo(PhotoVideoDetails())
        case .caterer: .catering(CateringDetails())
        case .eventSpace: .venue(VenueDetails())
        case .dj: .dj(DJDetails())
        case .baker: .baker(BakerDetails())
        case .florist: .florist(FloristDetails())
        case .decorator: .decorator(DecoratorDetails())
        case .entertainer: .entertainer(EntertainerDetails())
        case .rental: .rental(RentalDetails())
        case .bartender: .bartender(BartenderDetails())
        case .makeupArtist: .makeupArtist(MakeupArtistDetails())
        case .experienceStation: .experienceStation(ExperienceStationDetails())
        case .appetizer: .appetizer(AppetizerDetails())
        case .hairStylist: .hairStylist(HairStylistDetails())
        case .studio: .studio(StudioDetails())
        case .desserts: .desserts(DessertsDetails())
        case .photobooth: .photobooth(PhotoboothDetails())
        }
    }
}
