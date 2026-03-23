import SwiftUI

struct OnboardingEntertainerDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: EntertainerDetails {
        if case .entertainer(let d) = categoryDetails { return d }
        return EntertainerDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Entertainment type")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Describe your act or performance")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    TextField("e.g. Magician, Live band, Comedian", text: entertainmentTypeBinding)
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suitable age range")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    TextField("e.g. All ages, Adults only, Kids 3-12", text: ageRangeBinding)
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Interactive performance", isOn: isInteractiveBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    // MARK: - Bindings

    private var entertainmentTypeBinding: Binding<String> {
        Binding(
            get: { details.entertainmentType },
            set: { newValue in
                var updated = details
                updated.entertainmentType = newValue
                categoryDetails = .entertainer(updated)
            }
        )
    }

    private var ageRangeBinding: Binding<String> {
        Binding(
            get: { details.suitableAgeRange },
            set: { newValue in
                var updated = details
                updated.suitableAgeRange = newValue
                categoryDetails = .entertainer(updated)
            }
        )
    }

    private var isInteractiveBinding: Binding<Bool> {
        Binding(
            get: { details.isInteractive },
            set: { newValue in
                var updated = details
                updated.isInteractive = newValue
                categoryDetails = .entertainer(updated)
            }
        )
    }
}
