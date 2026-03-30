import SwiftUI

struct EntertainerDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                typesSection
                descriptionSection
                ageRangeSection
                interactiveSection
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

    private var typesSection: some View {
        EditableChipSection(
            title: "Entertainment type",
            subtitle: "What kind of entertainment do you offer?",
            options: EntertainerDetails.entertainmentTypeOptions,
            selected: typesBinding
        )
    }

    private var descriptionSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Describe your act")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Give hosts a sense of what to expect")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                TextField("e.g. High-energy magic show with audience participation", text: descriptionBinding)
            }
        }
    }

    private var ageRangeSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Suitable age range")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                TextField("e.g. All ages, Kids 3-10, Adults only", text: ageRangeBinding)
            }
        }
    }

    private var interactiveSection: some View {
        AppSurface {
            Toggle(isOn: interactiveBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interactive performance")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Does your act involve audience participation?")
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

    private var details: EntertainerDetails {
        if case .entertainer(let d) = store.draft.categoryDetails { return d }
        return EntertainerDetails()
    }

    private func updateDetails(_ details: EntertainerDetails) {
        store.draft.categoryDetails = .entertainer(details)
    }

    // MARK: - Bindings

    private var typesBinding: Binding<[String]> {
        Binding(
            get: { details.entertainmentTypes },
            set: { var d = details; d.entertainmentTypes = $0; updateDetails(d) }
        )
    }

    private var descriptionBinding: Binding<String> {
        Binding(
            get: { details.entertainmentType },
            set: { var d = details; d.entertainmentType = $0; updateDetails(d) }
        )
    }

    private var ageRangeBinding: Binding<String> {
        Binding(
            get: { details.suitableAgeRange },
            set: { var d = details; d.suitableAgeRange = $0; updateDetails(d) }
        )
    }

    private var interactiveBinding: Binding<Bool> {
        Binding(
            get: { details.isInteractive },
            set: { var d = details; d.isInteractive = $0; updateDetails(d) }
        )
    }
}
