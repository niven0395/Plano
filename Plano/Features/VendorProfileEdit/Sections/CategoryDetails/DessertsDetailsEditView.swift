import SwiftUI

struct DessertsDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                specialtiesSection
                dietarySection
                headcountSection
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
            subtitle: "What desserts do you offer?",
            options: DessertsDetails.specialtyOptions,
            selected: specialtiesBinding
        )
    }

    private var dietarySection: some View {
        EditableChipSection(
            title: "Dietary accommodations",
            options: DessertsDetails.dietaryOptions,
            selected: dietaryBinding
        )
    }

    private var headcountSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Minimum headcount")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Minimum number of guests required to book")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                TextField("e.g. 20", text: headcountBinding)
                    .keyboardType(.numberPad)
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

    private var details: DessertsDetails {
        if case .desserts(let d) = store.draft.categoryDetails { return d }
        return DessertsDetails()
    }

    private func updateDetails(_ details: DessertsDetails) {
        store.draft.categoryDetails = .desserts(details)
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
            get: { details.dietaryAccommodations },
            set: { var d = details; d.dietaryAccommodations = $0; updateDetails(d) }
        )
    }

    private var headcountBinding: Binding<String> {
        Binding(
            get: { if let v = details.servesMinimumHeadcount { String(v) } else { "" } },
            set: { var d = details; d.servesMinimumHeadcount = Int($0); updateDetails(d) }
        )
    }
}
