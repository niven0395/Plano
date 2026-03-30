import SwiftUI

struct FloristDetailsEditView: View {
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
            subtitle: "What floral services do you provide?",
            options: FloristDetails.serviceTypeOptions,
            selected: serviceTypesBinding
        )
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: deliverySetupBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delivery & setup included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you deliver and set up arrangements on-site?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: consultationBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Consultation included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you offer a design consultation before the event?")
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

    private var details: FloristDetails {
        if case .florist(let d) = store.draft.categoryDetails { return d }
        return FloristDetails()
    }

    private func updateDetails(_ details: FloristDetails) {
        store.draft.categoryDetails = .florist(details)
    }

    // MARK: - Bindings

    private var serviceTypesBinding: Binding<[String]> {
        Binding(
            get: { details.serviceTypes },
            set: { var d = details; d.serviceTypes = $0; updateDetails(d) }
        )
    }

    private var deliverySetupBinding: Binding<Bool> {
        Binding(
            get: { details.deliverySetupIncluded },
            set: { var d = details; d.deliverySetupIncluded = $0; updateDetails(d) }
        )
    }

    private var consultationBinding: Binding<Bool> {
        Binding(
            get: { details.consultationIncluded },
            set: { var d = details; d.consultationIncluded = $0; updateDetails(d) }
        )
    }
}
