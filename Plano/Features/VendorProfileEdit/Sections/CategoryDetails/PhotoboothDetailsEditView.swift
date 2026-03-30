import SwiftUI

struct PhotoboothDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                boothTypesSection
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

    private var boothTypesSection: some View {
        EditableChipSection(
            title: "Booth types",
            subtitle: "What photobooth setups do you offer?",
            options: PhotoboothDetails.boothTypeOptions,
            selected: boothTypesBinding
        )
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: propsBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Props included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you provide props and accessories?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: attendantBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attendant included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Does someone run the booth during the event?")
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

    private var details: PhotoboothDetails {
        if case .photobooth(let d) = store.draft.categoryDetails { return d }
        return PhotoboothDetails()
    }

    private func updateDetails(_ details: PhotoboothDetails) {
        store.draft.categoryDetails = .photobooth(details)
    }

    // MARK: - Bindings

    private var boothTypesBinding: Binding<[String]> {
        Binding(
            get: { details.boothTypes },
            set: { var d = details; d.boothTypes = $0; updateDetails(d) }
        )
    }

    private var propsBinding: Binding<Bool> {
        Binding(
            get: { details.propsIncluded },
            set: { var d = details; d.propsIncluded = $0; updateDetails(d) }
        )
    }

    private var attendantBinding: Binding<Bool> {
        Binding(
            get: { details.attendantIncluded },
            set: { var d = details; d.attendantIncluded = $0; updateDetails(d) }
        )
    }
}
