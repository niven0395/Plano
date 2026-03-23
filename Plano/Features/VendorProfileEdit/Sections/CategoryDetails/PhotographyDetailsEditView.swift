import SwiftUI

struct PhotographyDetailsEditView: View {
    let store: VendorProfileEditStore

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                deliverablesSection

                turnaroundSection

                secondShooterSection

                droneSection

                Button(store.loadingState.isLoading ? "Saving..." : "Save details") {
                    Task {
                        await store.save()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(store.loadingState.isLoading)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Details saved") {
            store.lastSaveOutcome = .idle
        }
    }

    // MARK: - Sections

    private var deliverablesSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Deliverables")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("What do clients receive?")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                let allOptions = photoVideoDetails.mediaType == .video
                    ? PhotoVideoDetails.videoDeliverableOptions
                    : PhotoVideoDetails.photoDeliverableOptions
                        + (photoVideoDetails.mediaType == .both ? PhotoVideoDetails.videoDeliverableOptions : [])

                FlowLayout(spacing: 8) {
                    ForEach(allOptions, id: \.self) { option in
                        Button {
                            toggleDeliverable(option)
                        } label: {
                            FilterChip(
                                title: option,
                                isSelected: photoVideoDetails.deliverables.contains(option)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var turnaroundSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Turnaround time")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("How long should clients expect to wait?")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                TextField("e.g. 2-3 weeks", text: turnaroundBinding)
            }
        }
    }

    private var secondShooterSection: some View {
        AppSurface {
            Toggle(isOn: secondShooterBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Second shooter available")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Can you provide a second photographer for larger events?")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }
            .tint(AppTheme.Palette.accent)
        }
    }

    private var droneSection: some View {
        AppSurface {
            Toggle(isOn: droneBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drone available")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Can you provide aerial footage?")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }
            .tint(AppTheme.Palette.accent)
        }
    }

    // MARK: - Data Access

    private var photoVideoDetails: PhotoVideoDetails {
        if case .photoVideo(let details) = store.draft.categoryDetails {
            return details
        }
        return PhotoVideoDetails()
    }

    private func updateDetails(_ details: PhotoVideoDetails) {
        store.draft.categoryDetails = .photoVideo(details)
    }

    private func toggleDeliverable(_ option: String) {
        var details = photoVideoDetails
        if details.deliverables.contains(option) {
            details.deliverables.removeAll { $0 == option }
        } else {
            details.deliverables.append(option)
        }
        updateDetails(details)
    }

    private var turnaroundBinding: Binding<String> {
        Binding(
            get: { photoVideoDetails.turnaroundNote },
            set: { newValue in
                var details = photoVideoDetails
                details.turnaroundNote = newValue
                updateDetails(details)
            }
        )
    }

    private var secondShooterBinding: Binding<Bool> {
        Binding(
            get: { photoVideoDetails.secondShooterAvailable },
            set: { newValue in
                var details = photoVideoDetails
                details.secondShooterAvailable = newValue
                updateDetails(details)
            }
        )
    }

    private var droneBinding: Binding<Bool> {
        Binding(
            get: { photoVideoDetails.droneAvailable },
            set: { newValue in
                var details = photoVideoDetails
                details.droneAvailable = newValue
                updateDetails(details)
            }
        )
    }
}
