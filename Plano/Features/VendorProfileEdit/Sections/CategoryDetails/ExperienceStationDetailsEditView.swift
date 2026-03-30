import SwiftUI

struct ExperienceStationDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stationTypeSection
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

    private var stationTypeSection: some View {
        EditableChipSection(
            title: "Station type",
            subtitle: "What kind of experience station do you run?",
            options: ExperienceStationDetails.stationTypeOptions,
            selected: stationTypeBinding
        )
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: setupBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Setup included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you handle setup at the venue?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: equipmentBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Equipment provided")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you bring all necessary equipment and supplies?")
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

    private var details: ExperienceStationDetails {
        if case .experienceStation(let d) = store.draft.categoryDetails { return d }
        return ExperienceStationDetails()
    }

    private func updateDetails(_ details: ExperienceStationDetails) {
        store.draft.categoryDetails = .experienceStation(details)
    }

    // MARK: - Bindings

    private var stationTypeBinding: Binding<[String]> {
        Binding(
            get: {
                let current = details.stationType.trimmingCharacters(in: .whitespacesAndNewlines)
                return current.isEmpty ? [] : [current]
            },
            set: { newValue in
                var d = details
                d.stationType = newValue.last ?? ""
                updateDetails(d)
            }
        )
    }

    private var setupBinding: Binding<Bool> {
        Binding(
            get: { details.setupIncluded },
            set: { var d = details; d.setupIncluded = $0; updateDetails(d) }
        )
    }

    private var equipmentBinding: Binding<Bool> {
        Binding(
            get: { details.equipmentProvided },
            set: { var d = details; d.equipmentProvided = $0; updateDetails(d) }
        )
    }
}
