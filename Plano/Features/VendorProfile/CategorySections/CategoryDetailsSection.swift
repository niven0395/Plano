import SwiftUI

struct CategoryDetailsSection: View {
    let details: CategoryDetails

    var body: some View {
        switch details {
        case .photoVideo(let d):
            PhotographyCategorySection(details: d)
        case .catering(let d):
            CateringCategorySection(details: d)
        case .venue(let d):
            VenueCategorySection(details: d)
        case .dj(let d):
            DJCategorySection(details: d)
        case .baker(let d):
            BakerCategorySection(details: d)
        case .florist(let d):
            FloristCategorySection(details: d)
        case .decorator(let d):
            DecoratorCategorySection(details: d)
        case .entertainer(let d):
            EntertainerCategorySection(details: d)
        case .rental(let d):
            RentalCategorySection(details: d)
        case .bartender(let d):
            BartenderCategorySection(details: d)
        case .makeupArtist(let d):
            MakeupArtistCategorySection(details: d)
        case .experienceStation(let d):
            ExperienceStationCategorySection(details: d)
        case .appetizer(let d):
            AppetizerCategorySection(details: d)
        case .hairStylist(let d):
            HairStylistCategorySection(details: d)
        case .studio(let d):
            StudioCategorySection(details: d)
        case .desserts(let d):
            DessertsCategorySection(details: d)
        case .photobooth(let d):
            PhotoboothCategorySection(details: d)
        }
    }
}
