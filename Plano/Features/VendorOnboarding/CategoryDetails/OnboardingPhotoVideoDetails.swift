import SwiftUI

struct OnboardingPhotoVideoDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: PhotoVideoDetails {
        if case .photoVideo(let d) = categoryDetails { return d }
        return PhotoVideoDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What do you offer?")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Picker("Media type", selection: mediaTypeBinding) {
                        ForEach(PhotoVideoMediaType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Deliverables")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: PhotoVideoDetails.photoDeliverableOptions + PhotoVideoDetails.videoDeliverableOptions,
                        selected: details.deliverables,
                        onToggle: { option in
                            var updated = details
                            if updated.deliverables.contains(option) {
                                updated.deliverables.removeAll { $0 == option }
                            } else {
                                updated.deliverables.append(option)
                            }
                            categoryDetails = .photoVideo(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Turnaround time")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    TextField("e.g. 2-4 weeks", text: turnaroundBinding)
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Second shooter available", isOn: secondShooterBinding)
                        .font(.subheadline.weight(.medium))
                    Toggle("Drone available", isOn: droneBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private var mediaTypeBinding: Binding<PhotoVideoMediaType> {
        Binding(
            get: { details.mediaType },
            set: { newValue in
                var updated = details
                updated.mediaType = newValue
                categoryDetails = .photoVideo(updated)
            }
        )
    }

    private var turnaroundBinding: Binding<String> {
        Binding(
            get: { details.turnaroundNote },
            set: { newValue in
                var updated = details
                updated.turnaroundNote = newValue
                categoryDetails = .photoVideo(updated)
            }
        )
    }

    private var secondShooterBinding: Binding<Bool> {
        Binding(
            get: { details.secondShooterAvailable },
            set: { newValue in
                var updated = details
                updated.secondShooterAvailable = newValue
                categoryDetails = .photoVideo(updated)
            }
        )
    }

    private var droneBinding: Binding<Bool> {
        Binding(
            get: { details.droneAvailable },
            set: { newValue in
                var updated = details
                updated.droneAvailable = newValue
                categoryDetails = .photoVideo(updated)
            }
        )
    }
}
