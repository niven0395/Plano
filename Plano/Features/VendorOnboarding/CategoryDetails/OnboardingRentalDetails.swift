import SwiftUI

struct OnboardingRentalDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: RentalDetails {
        if case .rental(let d) = categoryDetails { return d }
        return RentalDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rental categories")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Select all items you rent out")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    ChipFlowLayout(
                        options: RentalDetails.rentalCategoryOptions,
                        selected: details.rentalCategories,
                        onToggle: { option in
                            var updated = details
                            if updated.rentalCategories.contains(option) {
                                updated.rentalCategories.removeAll { $0 == option }
                            } else {
                                updated.rentalCategories.append(option)
                            }
                            categoryDetails = .rental(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Delivery & pickup included", isOn: deliveryPickupBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Setup included", isOn: setupBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    // MARK: - Bindings

    private var deliveryPickupBinding: Binding<Bool> {
        Binding(
            get: { details.deliveryPickupIncluded },
            set: { newValue in
                var updated = details
                updated.deliveryPickupIncluded = newValue
                categoryDetails = .rental(updated)
            }
        )
    }

    private var setupBinding: Binding<Bool> {
        Binding(
            get: { details.setupIncluded },
            set: { newValue in
                var updated = details
                updated.setupIncluded = newValue
                categoryDetails = .rental(updated)
            }
        )
    }
}
