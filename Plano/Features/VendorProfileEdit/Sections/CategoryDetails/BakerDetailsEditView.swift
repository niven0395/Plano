import SwiftUI

struct BakerDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                specialtiesSection
                dietarySection
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
            subtitle: "What do you make?",
            options: BakerDetails.specialtyOptions,
            selected: specialtiesBinding
        )
    }

    private var dietarySection: some View {
        EditableChipSection(
            title: "Dietary options",
            options: BakerDetails.availableDietaryOptions,
            selected: dietaryBinding
        )
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: tastingBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tasting available")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Can clients sample before ordering?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: deliveryBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delivery available")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Can you deliver to the event venue?")
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

    private var details: BakerDetails {
        if case .baker(let d) = store.draft.categoryDetails { return d }
        return BakerDetails()
    }

    private func updateDetails(_ details: BakerDetails) {
        store.draft.categoryDetails = .baker(details)
    }

    // MARK: - Bindings

    private var specialtiesBinding: Binding<[String]> {
        Binding(
            get: { details.specialties },
            set: { var d = details; d.specialties = $0; updateDetails(d) }
        )
    }

    private var dietaryBinding: Binding<[String]> {
        Binding(
            get: { details.dietaryOptions },
            set: { var d = details; d.dietaryOptions = $0; updateDetails(d) }
        )
    }

    private var tastingBinding: Binding<Bool> {
        Binding(
            get: { details.tastingAvailable },
            set: { var d = details; d.tastingAvailable = $0; updateDetails(d) }
        )
    }

    private var deliveryBinding: Binding<Bool> {
        Binding(
            get: { details.deliveryAvailable },
            set: { var d = details; d.deliveryAvailable = $0; updateDetails(d) }
        )
    }
}
