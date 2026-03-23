import SwiftUI

struct OnboardingDecoratorDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: DecoratorDetails {
        if case .decorator(let d) = categoryDetails { return d }
        return DecoratorDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Service types")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: DecoratorDetails.serviceTypeOptions,
                        selected: details.serviceTypes,
                        onToggle: { option in
                            var updated = details
                            if updated.serviceTypes.contains(option) {
                                updated.serviceTypes.removeAll { $0 == option }
                            } else {
                                updated.serviceTypes.append(option)
                            }
                            categoryDetails = .decorator(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Setup & teardown included", isOn: setupTeardownBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Materials provided", isOn: materialsBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    // MARK: - Bindings

    private var setupTeardownBinding: Binding<Bool> {
        Binding(
            get: { details.setupTeardownIncluded },
            set: { newValue in
                var updated = details
                updated.setupTeardownIncluded = newValue
                categoryDetails = .decorator(updated)
            }
        )
    }

    private var materialsBinding: Binding<Bool> {
        Binding(
            get: { details.materialsProvided },
            set: { newValue in
                var updated = details
                updated.materialsProvided = newValue
                categoryDetails = .decorator(updated)
            }
        )
    }
}
