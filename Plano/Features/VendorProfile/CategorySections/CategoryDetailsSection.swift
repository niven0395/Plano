import SwiftUI

struct CategoryDetailsSection: View {
    let details: CategoryDetails

    var body: some View {
        switch details {
        case .photoVideo(let d):
            PhotographyCategorySection(details: d)
        case .catering, .venue, .dj, .baker, .florist, .decorator,
             .entertainer, .rental,
             .bartender, .makeupArtist,
             .experienceStation, .appetizer,
             .hairStylist, .studio,
             .desserts, .photobooth:
            GenericCategorySection(details: details)
        }
    }
}
