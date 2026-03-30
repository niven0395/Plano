import SwiftUI

struct RentalDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                categoriesSection
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

    private var categoriesSection: some View {
        EditableChipSection(
            title: "Rental categories",
            subtitle: "What items do you rent out?",
            options: RentalDetails.rentalCategoryOptions,
            selected: categoriesBinding
        )
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: deliveryBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delivery & pickup included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you deliver and pick up rental items?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: setupBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Setup included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you set up the rental items on-site?")
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

    private var details: RentalDetails {
        if case .rental(let d) = store.draft.categoryDetails { return d }
        return RentalDetails()
    }

    private func updateDetails(_ details: RentalDetails) {
        store.draft.categoryDetails = .rental(details)
    }

    // MARK: - Bindings

    private var categoriesBinding: Binding<[String]> {
        Binding(
            get: { details.rentalCategories },
            set: { var d = details; d.rentalCategories = $0; updateDetails(d) }
        )
    }

    private var deliveryBinding: Binding<Bool> {
        Binding(
            get: { details.deliveryPickupIncluded },
            set: { var d = details; d.deliveryPickupIncluded = $0; updateDetails(d) }
        )
    }

    private var setupBinding: Binding<Bool> {
        Binding(
            get: { details.setupIncluded },
            set: { var d = details; d.setupIncluded = $0; updateDetails(d) }
        )
    }
}
