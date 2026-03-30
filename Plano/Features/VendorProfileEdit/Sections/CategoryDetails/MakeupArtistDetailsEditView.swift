import SwiftUI

struct MakeupArtistDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                specialtiesSection
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

    private var specialtiesSection: some View {
        EditableChipSection(
            title: "Specialties",
            subtitle: "What looks do you specialize in?",
            options: MakeupArtistDetails.specialtyOptions,
            selected: specialtiesBinding
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

                        Text("Do you offer a trial run before the event?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: hairBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hair services available")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you also offer hair styling?")
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

    private var details: MakeupArtistDetails {
        if case .makeupArtist(let d) = store.draft.categoryDetails { return d }
        return MakeupArtistDetails()
    }

    private func updateDetails(_ details: MakeupArtistDetails) {
        store.draft.categoryDetails = .makeupArtist(details)
    }

    // MARK: - Bindings

    private var specialtiesBinding: Binding<[String]> {
        Binding(
            get: { details.specialties },
            set: { var d = details; d.specialties = $0; updateDetails(d) }
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

    private var hairBinding: Binding<Bool> {
        Binding(
            get: { details.hairServicesAvailable },
            set: { var d = details; d.hairServicesAvailable = $0; updateDetails(d) }
        )
    }

    private var groupRatesBinding: Binding<Bool> {
        Binding(
            get: { details.groupRatesAvailable },
            set: { var d = details; d.groupRatesAvailable = $0; updateDetails(d) }
        )
    }
}
