import SwiftUI

struct StudioDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                studioTypeSection
                occupancySection
                equipmentSection
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

    private var studioTypeSection: some View {
        EditableChipSection(
            title: "Studio type",
            subtitle: "What kind of studio do you operate?",
            options: StudioDetails.studioTypeOptions,
            selected: studioTypeBinding
        )
    }

    private var occupancySection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Max occupancy")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("How many people can use the studio at once?")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                TextField("e.g. 10", text: occupancyBinding)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var equipmentSection: some View {
        AppSurface {
            Toggle(isOn: equipmentBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Equipment included")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Is studio equipment available for clients to use?")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }
            .tint(AppTheme.Palette.accent)
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

    private var details: StudioDetails {
        if case .studio(let d) = store.draft.categoryDetails { return d }
        return StudioDetails()
    }

    private func updateDetails(_ details: StudioDetails) {
        store.draft.categoryDetails = .studio(details)
    }

    // MARK: - Bindings

    private var studioTypeBinding: Binding<[String]> {
        Binding(
            get: {
                let current = details.studioType.trimmingCharacters(in: .whitespacesAndNewlines)
                return current.isEmpty ? [] : [current]
            },
            set: { newValue in
                var d = details
                d.studioType = newValue.last ?? ""
                updateDetails(d)
            }
        )
    }

    private var occupancyBinding: Binding<String> {
        Binding(
            get: { if let v = details.maxOccupancy { String(v) } else { "" } },
            set: { var d = details; d.maxOccupancy = Int($0); updateDetails(d) }
        )
    }

    private var equipmentBinding: Binding<Bool> {
        Binding(
            get: { details.equipmentIncluded },
            set: { var d = details; d.equipmentIncluded = $0; updateDetails(d) }
        )
    }
}
