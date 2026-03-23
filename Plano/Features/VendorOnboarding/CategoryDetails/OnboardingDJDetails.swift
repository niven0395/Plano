import SwiftUI

struct OnboardingDJDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: DJDetails {
        if case .dj(let d) = categoryDetails { return d }
        return DJDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Music genres")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Select all genres you play")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    ChipFlowLayout(
                        options: DJDetails.genreOptions,
                        selected: details.musicGenres,
                        onToggle: { option in
                            var updated = details
                            if updated.musicGenres.contains(option) {
                                updated.musicGenres.removeAll { $0 == option }
                            } else {
                                updated.musicGenres.append(option)
                            }
                            categoryDetails = .dj(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("MC services available", isOn: mcServicesBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Lighting package available", isOn: lightingBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    // MARK: - Bindings

    private var mcServicesBinding: Binding<Bool> {
        Binding(
            get: { details.mcServicesAvailable },
            set: { newValue in
                var updated = details
                updated.mcServicesAvailable = newValue
                categoryDetails = .dj(updated)
            }
        )
    }

    private var lightingBinding: Binding<Bool> {
        Binding(
            get: { details.lightingPackageAvailable },
            set: { newValue in
                var updated = details
                updated.lightingPackageAvailable = newValue
                categoryDetails = .dj(updated)
            }
        )
    }
}
