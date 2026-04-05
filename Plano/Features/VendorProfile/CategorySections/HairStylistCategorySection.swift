import SwiftUI

struct HairStylistCategorySection: View {
    let details: HairStylistDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.serviceTypes.isEmpty {
                    CategoryChipsGroup(title: "Services", items: details.serviceTypes)
                }

                if details.travelToVenue {
                    CategoryBooleanLabel(title: "Travels to venue", systemImage: "car.fill")
                }

                if details.trialIncluded {
                    CategoryBooleanLabel(title: "Trial included", systemImage: "calendar.badge.checkmark")
                }

                if details.groupRatesAvailable {
                    CategoryBooleanLabel(title: "Group rates available", systemImage: "person.3.fill")
                }
            }
        }
    }
}
