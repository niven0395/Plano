import SwiftUI

struct OnboardingAppetizerDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: AppetizerDetails {
        if case .appetizer(let d) = categoryDetails { return d }
        return AppetizerDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Service style")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Menu {
                        Picker("Service style", selection: serviceStyleBinding) {
                            Text("Not set").tag("")
                            ForEach(AppetizerDetails.serviceStyleOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                    } label: {
                        MenuDropdownRow(title: details.serviceStyle.isEmpty ? "Select..." : details.serviceStyle)
                    }
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dietary accommodations")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: AppetizerDetails.dietaryOptions,
                        selected: details.dietaryAccommodations,
                        onToggle: { option in
                            var updated = details
                            if updated.dietaryAccommodations.contains(option) {
                                updated.dietaryAccommodations.removeAll { $0 == option }
                            } else {
                                updated.dietaryAccommodations.append(option)
                            }
                            categoryDetails = .appetizer(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Minimum headcount")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    TextField("e.g. 20", text: minimumHeadcountBinding)
                        .keyboardType(.numberPad)
                }
            }
        }
    }

    private var serviceStyleBinding: Binding<String> {
        Binding(
            get: { details.serviceStyle },
            set: { newValue in
                var updated = details
                updated.serviceStyle = newValue
                categoryDetails = .appetizer(updated)
            }
        )
    }

    private var minimumHeadcountBinding: Binding<String> {
        Binding(
            get: { details.minimumHeadcount.map(String.init) ?? "" },
            set: { newValue in
                var updated = details
                updated.minimumHeadcount = Int(newValue)
                categoryDetails = .appetizer(updated)
            }
        )
    }
}
