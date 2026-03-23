import SwiftUI

struct OnboardingFloristDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: FloristDetails {
        if case .florist(let d) = categoryDetails { return d }
        return FloristDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Service types")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: FloristDetails.serviceTypeOptions,
                        selected: details.serviceTypes,
                        onToggle: { option in
                            var updated = details
                            if updated.serviceTypes.contains(option) {
                                updated.serviceTypes.removeAll { $0 == option }
                            } else {
                                updated.serviceTypes.append(option)
                            }
                            categoryDetails = .florist(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Delivery & setup included", isOn: deliverySetupBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Consultation included", isOn: consultationBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    // MARK: - Bindings

    private var deliverySetupBinding: Binding<Bool> {
        Binding(
            get: { details.deliverySetupIncluded },
            set: { newValue in
                var updated = details
                updated.deliverySetupIncluded = newValue
                categoryDetails = .florist(updated)
            }
        )
    }

    private var consultationBinding: Binding<Bool> {
        Binding(
            get: { details.consultationIncluded },
            set: { newValue in
                var updated = details
                updated.consultationIncluded = newValue
                categoryDetails = .florist(updated)
            }
        )
    }
}
