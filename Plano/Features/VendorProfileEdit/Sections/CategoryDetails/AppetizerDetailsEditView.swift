import SwiftUI

struct AppetizerDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                serviceStyleSection
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

    private var serviceStyleSection: some View {
        EditableChipSection(
            title: "Service style",
            subtitle: "How do you serve appetizers?",
            options: AppetizerDetails.serviceStyleOptions,
            selected: serviceStyleBinding
        )
    }

    private var dietarySection: some View {
        EditableChipSection(
            title: "Dietary accommodations",
            options: AppetizerDetails.dietaryOptions,
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

    private var details: AppetizerDetails {
        if case .appetizer(let d) = store.draft.categoryDetails { return d }
        return AppetizerDetails()
    }

    private func updateDetails(_ details: AppetizerDetails) {
        store.draft.categoryDetails = .appetizer(details)
    }

    // MARK: - Bindings

    private var serviceStyleBinding: Binding<[String]> {
        Binding(
            get: {
                let current = details.serviceStyle.trimmingCharacters(in: .whitespacesAndNewlines)
                return current.isEmpty ? [] : [current]
            },
            set: { newValue in
                var d = details
                d.serviceStyle = newValue.last ?? ""
                updateDetails(d)
            }
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
            get: { if let v = details.minimumHeadcount { String(v) } else { "" } },
            set: { var d = details; d.minimumHeadcount = Int($0); updateDetails(d) }
        )
    }
}
