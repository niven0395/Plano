import SwiftUI

struct OnboardingDessertsDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: DessertsDetails {
        if case .desserts(let d) = categoryDetails { return d }
        return DessertsDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Specialties")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: DessertsDetails.specialtyOptions,
                        selected: details.specialties,
                        onToggle: { option in
                            var updated = details
                            if updated.specialties.contains(option) {
                                updated.specialties.removeAll { $0 == option }
                            } else {
                                updated.specialties.append(option)
                            }
                            categoryDetails = .desserts(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dietary accommodations")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: DessertsDetails.dietaryOptions,
                        selected: details.dietaryAccommodations,
                        onToggle: { option in
                            var updated = details
                            if updated.dietaryAccommodations.contains(option) {
                                updated.dietaryAccommodations.removeAll { $0 == option }
                            } else {
                                updated.dietaryAccommodations.append(option)
                            }
                            categoryDetails = .desserts(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Minimum headcount")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    TextField("e.g. 20", text: servesMinimumHeadcountBinding)
                        .keyboardType(.numberPad)
                }
            }
        }
    }

    private var servesMinimumHeadcountBinding: Binding<String> {
        Binding(
            get: { details.servesMinimumHeadcount.map(String.init) ?? "" },
            set: { newValue in
                var updated = details
                updated.servesMinimumHeadcount = Int(newValue)
                categoryDetails = .desserts(updated)
            }
        )
    }
}
