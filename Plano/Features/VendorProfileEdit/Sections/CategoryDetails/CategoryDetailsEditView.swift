import SwiftUI

struct CategoryDetailsEditView: View {
    let store: VendorProfileEditStore

    var body: some View {
        Group {
            switch store.draft.category {
            case .photographer:
                PhotographyDetailsEditView(store: store)
            case .eventSpace:
                VenueDetailsEditView(store: store)
            case .caterer:
                CateringDetailsEditView(store: store)
            case .dj:
                DJDetailsEditView(store: store)
            case .baker:
                BakerDetailsEditView(store: store)
            case .florist:
                FloristDetailsEditView(store: store)
            case .decorator:
                DecoratorDetailsEditView(store: store)
            case .entertainer:
                EntertainerDetailsEditView(store: store)
            case .rental:
                RentalDetailsEditView(store: store)
            case .bartender:
                BartenderDetailsEditView(store: store)
            case .makeupArtist:
                MakeupArtistDetailsEditView(store: store)
            case .experienceStation:
                ExperienceStationDetailsEditView(store: store)
            case .appetizer:
                AppetizerDetailsEditView(store: store)
            case .hairStylist:
                HairStylistDetailsEditView(store: store)
            case .studio:
                StudioDetailsEditView(store: store)
            case .desserts:
                DessertsDetailsEditView(store: store)
            case .photobooth:
                PhotoboothDetailsEditView(store: store)
            }
        }
        .navigationTitle(store.draft.categoryDetails?.sectionTitle ?? categoryDetailsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var categoryDetailsTitle: String {
        CategoryDetails.empty(for: store.draft.category).sectionTitle
    }
}
