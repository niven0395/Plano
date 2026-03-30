import SwiftUI

struct DJDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                genresSection
                togglesSection
                saveButton
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

    private var genresSection: some View {
        EditableChipSection(
            title: "Music genres",
            subtitle: "What genres do you play?",
            options: DJDetails.genreOptions,
            selected: genresBinding
        )
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: mcBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MC services available")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Can you emcee the event?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: lightingBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lighting package available")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you offer lighting with your DJ setup?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)
            }
        }
    }

    private var saveButton: some View {
        Button(store.loadingState.isLoading ? "Saving..." : "Save details") {
            Task {
                await store.save()
                if store.lastSaveOutcome == .saved { dismiss() }
            }
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(store.loadingState.isLoading)
    }

    // MARK: - Data Access

    private var details: DJDetails {
        if case .dj(let d) = store.draft.categoryDetails { return d }
        return DJDetails()
    }

    private func updateDetails(_ details: DJDetails) {
        store.draft.categoryDetails = .dj(details)
    }

    // MARK: - Bindings

    private var genresBinding: Binding<[String]> {
        Binding(
            get: { details.musicGenres },
            set: { var d = details; d.musicGenres = $0; updateDetails(d) }
        )
    }

    private var mcBinding: Binding<Bool> {
        Binding(
            get: { details.mcServicesAvailable },
            set: { var d = details; d.mcServicesAvailable = $0; updateDetails(d) }
        )
    }

    private var lightingBinding: Binding<Bool> {
        Binding(
            get: { details.lightingPackageAvailable },
            set: { var d = details; d.lightingPackageAvailable = $0; updateDetails(d) }
        )
    }
}
