import SwiftUI

struct OnboardingCateringDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: CateringDetails {
        if case .catering(let d) = categoryDetails { return d }
        return CateringDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cuisine types")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Select all cuisines you offer")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    ChipFlowLayout(
                        options: CateringDetails.cuisineOptions,
                        selected: details.cuisineTypes,
                        onToggle: { option in
                            var updated = details
                            if updated.cuisineTypes.contains(option) {
                                updated.cuisineTypes.removeAll { $0 == option }
                            } else {
                                updated.cuisineTypes.append(option)
                            }
                            categoryDetails = .catering(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Service styles")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: CateringDetails.serviceStyleOptions,
                        selected: details.serviceStyles,
                        onToggle: { option in
                            var updated = details
                            if updated.serviceStyles.contains(option) {
                                updated.serviceStyles.removeAll { $0 == option }
                            } else {
                                updated.serviceStyles.append(option)
                            }
                            categoryDetails = .catering(updated)
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
                        options: CateringDetails.dietaryOptions,
                        selected: details.dietaryAccommodations,
                        onToggle: { option in
                            var updated = details
                            if updated.dietaryAccommodations.contains(option) {
                                updated.dietaryAccommodations.removeAll { $0 == option }
                            } else {
                                updated.dietaryAccommodations.append(option)
                            }
                            categoryDetails = .catering(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Tasting available", isOn: tastingBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Serving staff included", isOn: servingStaffBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Tableware included", isOn: tablewareBinding)
                        .font(.subheadline.weight(.medium))
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Guest count range")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    HStack(spacing: 12) {
                        TextField("Min", text: minimumHeadcountBinding)
                            .keyboardType(.numberPad)
                        Text("to")
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                        TextField("Max", text: maximumHeadcountBinding)
                            .keyboardType(.numberPad)
                    }
                }
            }
        }
    }

    // MARK: - Bindings

    private var tastingBinding: Binding<Bool> {
        Binding(
            get: { details.tastingAvailable },
            set: { newValue in
                var updated = details
                updated.tastingAvailable = newValue
                categoryDetails = .catering(updated)
            }
        )
    }

    private var servingStaffBinding: Binding<Bool> {
        Binding(
            get: { details.servingStaffIncluded },
            set: { newValue in
                var updated = details
                updated.servingStaffIncluded = newValue
                categoryDetails = .catering(updated)
            }
        )
    }

    private var tablewareBinding: Binding<Bool> {
        Binding(
            get: { details.tablewareIncluded },
            set: { newValue in
                var updated = details
                updated.tablewareIncluded = newValue
                categoryDetails = .catering(updated)
            }
        )
    }

    private var minimumHeadcountBinding: Binding<String> {
        Binding(
            get: {
                if let value = details.minimumHeadcount { String(value) } else { "" }
            },
            set: { newValue in
                var updated = details
                updated.minimumHeadcount = Int(newValue)
                categoryDetails = .catering(updated)
            }
        )
    }

    private var maximumHeadcountBinding: Binding<String> {
        Binding(
            get: {
                if let value = details.maximumHeadcount { String(value) } else { "" }
            },
            set: { newValue in
                var updated = details
                updated.maximumHeadcount = Int(newValue)
                categoryDetails = .catering(updated)
            }
        )
    }
}
