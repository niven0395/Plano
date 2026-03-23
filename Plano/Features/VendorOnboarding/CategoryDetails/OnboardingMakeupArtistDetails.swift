import SwiftUI

struct OnboardingMakeupArtistDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: MakeupArtistDetails {
        if case .makeupArtist(let d) = categoryDetails { return d }
        return MakeupArtistDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Travel to venue", isOn: travelToVenueBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Trial session included", isOn: trialIncludedBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Hair services available", isOn: hairServicesAvailableBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Group rates available", isOn: groupRatesAvailableBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private var travelToVenueBinding: Binding<Bool> {
        Binding(
            get: { details.travelToVenue },
            set: { newValue in
                var updated = details
                updated.travelToVenue = newValue
                categoryDetails = .makeupArtist(updated)
            }
        )
    }

    private var trialIncludedBinding: Binding<Bool> {
        Binding(
            get: { details.trialIncluded },
            set: { newValue in
                var updated = details
                updated.trialIncluded = newValue
                categoryDetails = .makeupArtist(updated)
            }
        )
    }

    private var hairServicesAvailableBinding: Binding<Bool> {
        Binding(
            get: { details.hairServicesAvailable },
            set: { newValue in
                var updated = details
                updated.hairServicesAvailable = newValue
                categoryDetails = .makeupArtist(updated)
            }
        )
    }

    private var groupRatesAvailableBinding: Binding<Bool> {
        Binding(
            get: { details.groupRatesAvailable },
            set: { newValue in
                var updated = details
                updated.groupRatesAvailable = newValue
                categoryDetails = .makeupArtist(updated)
            }
        )
    }
}
