import SwiftUI

struct OnboardingBakerDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: BakerDetails {
        if case .baker(let d) = categoryDetails { return d }
        return BakerDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Specialties")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: BakerDetails.specialtyOptions,
                        selected: details.specialties,
                        onToggle: { option in
                            var updated = details
                            if updated.specialties.contains(option) {
                                updated.specialties.removeAll { $0 == option }
                            } else {
                                updated.specialties.append(option)
                            }
                            categoryDetails = .baker(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dietary options")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: BakerDetails.availableDietaryOptions,
                        selected: details.dietaryOptions,
                        onToggle: { option in
                            var updated = details
                            if updated.dietaryOptions.contains(option) {
                                updated.dietaryOptions.removeAll { $0 == option }
                            } else {
                                updated.dietaryOptions.append(option)
                            }
                            categoryDetails = .baker(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Tasting available", isOn: tastingBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Delivery available", isOn: deliveryBinding)
                        .font(.subheadline.weight(.medium))
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
                categoryDetails = .baker(updated)
            }
        )
    }

    private var deliveryBinding: Binding<Bool> {
        Binding(
            get: { details.deliveryAvailable },
            set: { newValue in
                var updated = details
                updated.deliveryAvailable = newValue
                categoryDetails = .baker(updated)
            }
        )
    }
}
