import SwiftUI

struct OnboardingPhotoboothDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: PhotoboothDetails {
        if case .photobooth(let d) = categoryDetails { return d }
        return PhotoboothDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Booth types")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: PhotoboothDetails.boothTypeOptions,
                        selected: details.boothTypes,
                        onToggle: { option in
                            var updated = details
                            if updated.boothTypes.contains(option) {
                                updated.boothTypes.removeAll { $0 == option }
                            } else {
                                updated.boothTypes.append(option)
                            }
                            categoryDetails = .photobooth(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Props included", isOn: propsBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Attendant included", isOn: attendantBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private var propsBinding: Binding<Bool> {
        Binding(
            get: { details.propsIncluded },
            set: { newValue in
                var updated = details
                updated.propsIncluded = newValue
                categoryDetails = .photobooth(updated)
            }
        )
    }

    private var attendantBinding: Binding<Bool> {
        Binding(
            get: { details.attendantIncluded },
            set: { newValue in
                var updated = details
                updated.attendantIncluded = newValue
                categoryDetails = .photobooth(updated)
            }
        )
    }
}
