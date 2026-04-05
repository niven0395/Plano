import SwiftUI

struct MakeupArtistCategorySection: View {
    let details: MakeupArtistDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.specialties.isEmpty {
                    CategoryChipsGroup(title: "Specialties", items: details.specialties)
                }

                if details.travelToVenue {
                    CategoryBooleanLabel(title: "Travels to venue", systemImage: "car.fill")
                }

                if details.trialIncluded {
                    CategoryBooleanLabel(title: "Trial included", systemImage: "calendar.badge.checkmark")
                }

                if details.hairServicesAvailable {
                    CategoryBooleanLabel(title: "Hair services available", systemImage: "scissors")
                }

                if details.groupRatesAvailable {
                    CategoryBooleanLabel(title: "Group rates available", systemImage: "person.3.fill")
                }
            }
        }
    }
}
