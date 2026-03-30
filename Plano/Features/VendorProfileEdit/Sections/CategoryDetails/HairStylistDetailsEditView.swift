import SwiftUI

struct HairStylistDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                serviceTypesSection
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

    private var serviceTypesSection: some View {
        EditableChipSection(
            title: "Services offered",
            subtitle: "What styling services do you provide?",
            options: HairStylistDetails.serviceTypeOptions,
            selected: serviceTypesBinding
        )
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: travelBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Travel to venue")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you travel to the client's location?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: trialBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trial session included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you offer a trial before the event?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: groupRatesBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Group rates available")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you offer discounts for bridal parties or groups?")
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

    private var details: HairStylistDetails {
        if case .hairStylist(let d) = store.draft.categoryDetails { return d }
        return HairStylistDetails()
    }

    private func updateDetails(_ details: HairStylistDetails) {
        store.draft.categoryDetails = .hairStylist(details)
    }

    // MARK: - Bindings

    private var serviceTypesBinding: Binding<[String]> {
        Binding(
            get: { details.serviceTypes },
            set: { var d = details; d.serviceTypes = $0; updateDetails(d) }
        )
    }

    private var travelBinding: Binding<Bool> {
        Binding(
            get: { details.travelToVenue },
            set: { var d = details; d.travelToVenue = $0; updateDetails(d) }
        )
    }

    private var trialBinding: Binding<Bool> {
        Binding(
            get: { details.trialIncluded },
            set: { var d = details; d.trialIncluded = $0; updateDetails(d) }
        )
    }

    private var groupRatesBinding: Binding<Bool> {
        Binding(
            get: { details.groupRatesAvailable },
            set: { var d = details; d.groupRatesAvailable = $0; updateDetails(d) }
        )
    }
}
