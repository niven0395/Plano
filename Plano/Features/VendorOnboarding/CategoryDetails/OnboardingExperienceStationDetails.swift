import SwiftUI

struct OnboardingExperienceStationDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: ExperienceStationDetails {
        if case .experienceStation(let d) = categoryDetails { return d }
        return ExperienceStationDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Station type")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Menu {
                        Picker("Station type", selection: stationTypeBinding) {
                            Text("Not set").tag("")
                            ForEach(ExperienceStationDetails.stationTypeOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                    } label: {
                        MenuDropdownRow(title: details.stationType.isEmpty ? "Select..." : details.stationType)
                    }
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Setup included", isOn: setupIncludedBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Equipment provided", isOn: equipmentProvidedBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private var stationTypeBinding: Binding<String> {
        Binding(
            get: { details.stationType },
            set: { newValue in
                var updated = details
                updated.stationType = newValue
                categoryDetails = .experienceStation(updated)
            }
        )
    }

    private var setupIncludedBinding: Binding<Bool> {
        Binding(
            get: { details.setupIncluded },
            set: { newValue in
                var updated = details
                updated.setupIncluded = newValue
                categoryDetails = .experienceStation(updated)
            }
        )
    }

    private var equipmentProvidedBinding: Binding<Bool> {
        Binding(
            get: { details.equipmentProvided },
            set: { newValue in
                var updated = details
                updated.equipmentProvided = newValue
                categoryDetails = .experienceStation(updated)
            }
        )
    }
}
