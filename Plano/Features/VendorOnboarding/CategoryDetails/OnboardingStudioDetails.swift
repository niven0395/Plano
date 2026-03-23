import SwiftUI

struct OnboardingStudioDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: StudioDetails {
        if case .studio(let d) = categoryDetails { return d }
        return StudioDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Studio type")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Menu {
                        Picker("Studio type", selection: studioTypeBinding) {
                            Text("Not set").tag("")
                            ForEach(StudioDetails.studioTypeOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                    } label: {
                        MenuDropdownRow(title: details.studioType.isEmpty ? "Select..." : details.studioType)
                    }
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Equipment included", isOn: equipmentIncludedBinding)
                        .font(.subheadline.weight(.medium))
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Max occupancy")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    TextField("e.g. 50", text: maxOccupancyBinding)
                        .keyboardType(.numberPad)
                }
            }
        }
    }

    private var studioTypeBinding: Binding<String> {
        Binding(
            get: { details.studioType },
            set: { newValue in
                var updated = details
                updated.studioType = newValue
                categoryDetails = .studio(updated)
            }
        )
    }

    private var equipmentIncludedBinding: Binding<Bool> {
        Binding(
            get: { details.equipmentIncluded },
            set: { newValue in
                var updated = details
                updated.equipmentIncluded = newValue
                categoryDetails = .studio(updated)
            }
        )
    }

    private var maxOccupancyBinding: Binding<String> {
        Binding(
            get: { details.maxOccupancy.map(String.init) ?? "" },
            set: { newValue in
                var updated = details
                updated.maxOccupancy = Int(newValue)
                categoryDetails = .studio(updated)
            }
        )
    }
}
