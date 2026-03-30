import SwiftUI

struct DecoratorDetailsEditView: View {
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
            subtitle: "What decor services do you provide?",
            options: DecoratorDetails.serviceTypeOptions,
            selected: serviceTypesBinding
        )
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: setupTeardownBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Setup & teardown included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you handle setup and cleanup?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: materialsBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Materials provided")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Are all decor materials included in your pricing?")
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

    private var details: DecoratorDetails {
        if case .decorator(let d) = store.draft.categoryDetails { return d }
        return DecoratorDetails()
    }

    private func updateDetails(_ details: DecoratorDetails) {
        store.draft.categoryDetails = .decorator(details)
    }

    // MARK: - Bindings

    private var serviceTypesBinding: Binding<[String]> {
        Binding(
            get: { details.serviceTypes },
            set: { var d = details; d.serviceTypes = $0; updateDetails(d) }
        )
    }

    private var setupTeardownBinding: Binding<Bool> {
        Binding(
            get: { details.setupTeardownIncluded },
            set: { var d = details; d.setupTeardownIncluded = $0; updateDetails(d) }
        )
    }

    private var materialsBinding: Binding<Bool> {
        Binding(
            get: { details.materialsProvided },
            set: { var d = details; d.materialsProvided = $0; updateDetails(d) }
        )
    }
}
