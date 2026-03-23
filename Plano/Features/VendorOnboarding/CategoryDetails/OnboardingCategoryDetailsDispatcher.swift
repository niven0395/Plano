import SwiftUI

struct OnboardingCategoryDetailsDispatcher: View {
    let category: VendorCategory
    @Binding var categoryDetails: CategoryDetails?

    var body: some View {
        switch category {
        case .photographer:
            OnboardingPhotoVideoDetails(categoryDetails: $categoryDetails)
        case .caterer:
            OnboardingCateringDetails(categoryDetails: $categoryDetails)
        case .eventSpace:
            OnboardingVenueDetails(categoryDetails: $categoryDetails)
        case .dj:
            OnboardingDJDetails(categoryDetails: $categoryDetails)
        case .baker:
            OnboardingBakerDetails(categoryDetails: $categoryDetails)
        case .florist:
            OnboardingFloristDetails(categoryDetails: $categoryDetails)
        case .decorator:
            OnboardingDecoratorDetails(categoryDetails: $categoryDetails)
        case .entertainer:
            OnboardingEntertainerDetails(categoryDetails: $categoryDetails)
        case .rental:
            OnboardingRentalDetails(categoryDetails: $categoryDetails)
        case .bartender:
            OnboardingBartenderDetails(categoryDetails: $categoryDetails)
        case .makeupArtist:
            OnboardingMakeupArtistDetails(categoryDetails: $categoryDetails)
        case .experienceStation:
            OnboardingExperienceStationDetails(categoryDetails: $categoryDetails)
        case .appetizer:
            OnboardingAppetizerDetails(categoryDetails: $categoryDetails)
        case .hairStylist:
            OnboardingHairStylistDetails(categoryDetails: $categoryDetails)
        case .studio:
            OnboardingStudioDetails(categoryDetails: $categoryDetails)
        case .desserts:
            OnboardingDessertsDetails(categoryDetails: $categoryDetails)
        case .photobooth:
            OnboardingPhotoboothDetails(categoryDetails: $categoryDetails)
        }
    }
}
