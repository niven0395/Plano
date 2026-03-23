import SwiftUI

struct OnboardingBartenderDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: BartenderDetails {
        if case .bartender(let d) = categoryDetails { return d }
        return BartenderDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bar types")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: BartenderDetails.barTypeOptions,
                        selected: details.barTypes,
                        onToggle: { option in
                            var updated = details
                            if updated.barTypes.contains(option) {
                                updated.barTypes.removeAll { $0 == option }
                            } else {
                                updated.barTypes.append(option)
                            }
                            categoryDetails = .bartender(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Signature cocktails", isOn: signatureCocktailsBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Equipment provided", isOn: equipmentProvidedBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Ingredients included", isOn: ingredientsIncludedBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private var signatureCocktailsBinding: Binding<Bool> {
        Binding(
            get: { details.signatureCocktails },
            set: { newValue in
                var updated = details
                updated.signatureCocktails = newValue
                categoryDetails = .bartender(updated)
            }
        )
    }

    private var equipmentProvidedBinding: Binding<Bool> {
        Binding(
            get: { details.equipmentProvided },
            set: { newValue in
                var updated = details
                updated.equipmentProvided = newValue
                categoryDetails = .bartender(updated)
            }
        )
    }

    private var ingredientsIncludedBinding: Binding<Bool> {
        Binding(
            get: { details.ingredientsIncluded },
            set: { newValue in
                var updated = details
                updated.ingredientsIncluded = newValue
                categoryDetails = .bartender(updated)
            }
        )
    }
}
