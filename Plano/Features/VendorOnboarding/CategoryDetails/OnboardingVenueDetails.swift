import SwiftUI

struct OnboardingVenueDetails: View {
    @Binding var categoryDetails: CategoryDetails?

    private var details: VenueDetails {
        if case .venue(let d) = categoryDetails { return d }
        return VenueDetails()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Event types")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: VenueDetails.eventTypeOptions,
                        selected: details.eventTypes,
                        onToggle: { option in
                            var updated = details
                            if updated.eventTypes.contains(option) {
                                updated.eventTypes.removeAll { $0 == option }
                            } else {
                                updated.eventTypes.append(option)
                            }
                            categoryDetails = .venue(updated)
                        }
                    )
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Included amenities")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ChipFlowLayout(
                        options: VenueDetails.amenityOptions,
                        selected: details.includedAmenities,
                        onToggle: { option in
                            var updated = details
                            if updated.includedAmenities.contains(option) {
                                updated.includedAmenities.removeAll { $0 == option }
                            } else {
                                updated.includedAmenities.append(option)
                            }
                            categoryDetails = .venue(updated)
                        }
                    )
                }
            }

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

            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Setup & teardown included", isOn: setupTeardownBinding)
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    // MARK: - Bindings

    private var seatedCapacityBinding: Binding<String> {
        Binding(
            get: {
                if let value = details.seatedCapacity { String(value) } else { "" }
            },
            set: { newValue in
                var updated = details
                updated.seatedCapacity = Int(newValue)
                categoryDetails = .venue(updated)
            }
        )
    }

    private var standingCapacityBinding: Binding<String> {
        Binding(
            get: {
                if let value = details.standingCapacity { String(value) } else { "" }
            },
            set: { newValue in
                var updated = details
                updated.standingCapacity = Int(newValue)
                categoryDetails = .venue(updated)
            }
        )
    }

    private var venueStyleBinding: Binding<String> {
        Binding(
            get: { details.venueStyle },
            set: { newValue in
                var updated = details
                updated.venueStyle = newValue
                categoryDetails = .venue(updated)
            }
        )
    }

    private var alcoholPolicyBinding: Binding<String> {
        Binding(
            get: { details.alcoholPolicy },
            set: { newValue in
                var updated = details
                updated.alcoholPolicy = newValue
                categoryDetails = .venue(updated)
            }
        )
    }

    private var cateringPolicyBinding: Binding<String> {
        Binding(
            get: { details.cateringPolicy },
            set: { newValue in
                var updated = details
                updated.cateringPolicy = newValue
                categoryDetails = .venue(updated)
            }
        )
    }

    private var setupTeardownBinding: Binding<Bool> {
        Binding(
            get: { details.setupTeardownIncluded },
            set: { newValue in
                var updated = details
                updated.setupTeardownIncluded = newValue
                categoryDetails = .venue(updated)
            }
        )
    }
}
