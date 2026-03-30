import SwiftUI

struct BartenderDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                barTypesSection
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

    private var barTypesSection: some View {
        EditableChipSection(
            title: "Bar service types",
            subtitle: "What bar packages do you offer?",
            options: BartenderDetails.barTypeOptions,
            selected: barTypesBinding
        )
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: signatureCocktailsBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signature cocktails")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Can you create custom cocktails for the event?")
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

                        Text("Do you bring your own bar setup and tools?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: ingredientsBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ingredients included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you supply the alcohol and mixers?")
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

    private var details: BartenderDetails {
        if case .bartender(let d) = store.draft.categoryDetails { return d }
        return BartenderDetails()
    }

    private func updateDetails(_ details: BartenderDetails) {
        store.draft.categoryDetails = .bartender(details)
    }

    // MARK: - Bindings

    private var barTypesBinding: Binding<[String]> {
        Binding(
            get: { details.barTypes },
            set: { var d = details; d.barTypes = $0; updateDetails(d) }
        )
    }

    private var signatureCocktailsBinding: Binding<Bool> {
        Binding(
            get: { details.signatureCocktails },
            set: { var d = details; d.signatureCocktails = $0; updateDetails(d) }
        )
    }

    private var equipmentBinding: Binding<Bool> {
        Binding(
            get: { details.equipmentProvided },
            set: { var d = details; d.equipmentProvided = $0; updateDetails(d) }
        )
    }

    private var ingredientsBinding: Binding<Bool> {
        Binding(
            get: { details.ingredientsIncluded },
            set: { var d = details; d.ingredientsIncluded = $0; updateDetails(d) }
        )
    }
}
