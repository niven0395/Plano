import SwiftUI

struct VenueDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                capacitySection
                venueStyleSection
                eventTypesSection
                amenitiesSection
                alcoholPolicySection
                cateringPolicySection
                parkingSection
                noiseRestrictionSection
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

    private var capacitySection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Capacity")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Seated")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                        TextField("e.g. 150", text: seatedCapacityBinding)
                            .keyboardType(.numberPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Standing")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                        TextField("e.g. 300", text: standingCapacityBinding)
                            .keyboardType(.numberPad)
                    }
                }
            }
        }
    }

    private var venueStyleSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Venue style")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Menu {
                    Picker("Venue style", selection: venueStyleBinding) {
                        Text("Not set").tag("")
                        ForEach(VenueDetails.venueStyleOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                } label: {
                    MenuDropdownRow(
                        title: details.venueStyle.isEmpty ? "Select..." : details.venueStyle
                    )
                }
            }
        }
    }

    private var eventTypesSection: some View {
        EditableChipSection(
            title: "Event types",
            subtitle: "What kinds of events do you host?",
            options: VenueDetails.eventTypeOptions,
            selected: eventTypesBinding
        )
    }

    private var amenitiesSection: some View {
        EditableChipSection(
            title: "Included amenities",
            subtitle: "What comes with the space?",
            options: VenueDetails.amenityOptions,
            selected: amenitiesBinding
        )
    }

    private var alcoholPolicySection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Alcohol policy")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Menu {
                    Picker("Alcohol policy", selection: alcoholPolicyBinding) {
                        Text("Not set").tag("")
                        ForEach(VenueDetails.alcoholPolicyOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                } label: {
                    MenuDropdownRow(
                        title: details.alcoholPolicy.isEmpty ? "Select..." : details.alcoholPolicy
                    )
                }
            }
        }
    }

    private var cateringPolicySection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Catering policy")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Menu {
                    Picker("Catering policy", selection: cateringPolicyBinding) {
                        Text("Not set").tag("")
                        ForEach(VenueDetails.cateringPolicyOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                } label: {
                    MenuDropdownRow(
                        title: details.cateringPolicy.isEmpty ? "Select..." : details.cateringPolicy
                    )
                }
            }
        }
    }

    private var parkingSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Parking")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Describe the parking situation for guests")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                TextField("e.g. Free lot for 50 cars", text: parkingNoteBinding)
            }
        }
    }

    private var noiseRestrictionSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Noise restrictions")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                TextField("e.g. Music off by 10 PM", text: noiseRestrictionBinding)
            }
        }
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: bartenderBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bartender included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Is a bartender provided with the venue?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

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
            }
        }
    }

    private var saveButton: some View {
        Button(store.loadingState.isLoading ? "Saving..." : "Save details") {
            Task {
                await store.save()
                if store.lastSaveOutcome == .saved {
                    dismiss()
                }
            }
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(store.loadingState.isLoading)
    }

    // MARK: - Data Access

    private var details: VenueDetails {
        if case .venue(let d) = store.draft.categoryDetails { return d }
        return VenueDetails()
    }

    private func updateDetails(_ details: VenueDetails) {
        store.draft.categoryDetails = .venue(details)
    }

    // MARK: - Bindings

    private var seatedCapacityBinding: Binding<String> {
        Binding(
            get: { if let v = details.seatedCapacity { String(v) } else { "" } },
            set: { var d = details; d.seatedCapacity = Int($0); updateDetails(d) }
        )
    }

    private var standingCapacityBinding: Binding<String> {
        Binding(
            get: { if let v = details.standingCapacity { String(v) } else { "" } },
            set: { var d = details; d.standingCapacity = Int($0); updateDetails(d) }
        )
    }

    private var venueStyleBinding: Binding<String> {
        Binding(
            get: { details.venueStyle },
            set: { var d = details; d.venueStyle = $0; updateDetails(d) }
        )
    }

    private var eventTypesBinding: Binding<[String]> {
        Binding(
            get: { details.eventTypes },
            set: { var d = details; d.eventTypes = $0; updateDetails(d) }
        )
    }

    private var amenitiesBinding: Binding<[String]> {
        Binding(
            get: { details.includedAmenities },
            set: { var d = details; d.includedAmenities = $0; updateDetails(d) }
        )
    }

    private var alcoholPolicyBinding: Binding<String> {
        Binding(
            get: { details.alcoholPolicy },
            set: { var d = details; d.alcoholPolicy = $0; updateDetails(d) }
        )
    }

    private var cateringPolicyBinding: Binding<String> {
        Binding(
            get: { details.cateringPolicy },
            set: { var d = details; d.cateringPolicy = $0; updateDetails(d) }
        )
    }

    private var parkingNoteBinding: Binding<String> {
        Binding(
            get: { details.parkingNote },
            set: { var d = details; d.parkingNote = $0; updateDetails(d) }
        )
    }

    private var noiseRestrictionBinding: Binding<String> {
        Binding(
            get: { details.noiseRestriction },
            set: { var d = details; d.noiseRestriction = $0; updateDetails(d) }
        )
    }

    private var bartenderBinding: Binding<Bool> {
        Binding(
            get: { details.bartenderIncluded },
            set: { var d = details; d.bartenderIncluded = $0; updateDetails(d) }
        )
    }

    private var setupTeardownBinding: Binding<Bool> {
        Binding(
            get: { details.setupTeardownIncluded },
            set: { var d = details; d.setupTeardownIncluded = $0; updateDetails(d) }
        )
    }
}
