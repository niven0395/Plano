import SwiftUI

struct CateringDetailsEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cuisineSection
                serviceStylesSection
                dietarySection
                headcountSection
                togglesSection
                menuSectionsSection
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

    private var cuisineSection: some View {
        EditableChipSection(
            title: "Cuisine types",
            subtitle: "What cuisines do you offer?",
            options: CateringDetails.cuisineOptions,
            selected: cuisineBinding
        )
    }

    private var serviceStylesSection: some View {
        EditableChipSection(
            title: "Service styles",
            subtitle: "How do you serve?",
            options: CateringDetails.serviceStyleOptions,
            selected: serviceStylesBinding
        )
    }

    private var dietarySection: some View {
        EditableChipSection(
            title: "Dietary accommodations",
            options: CateringDetails.dietaryOptions,
            selected: dietaryBinding
        )
    }

    private var headcountSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Guest count range")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minimum")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                        TextField("e.g. 20", text: minHeadcountBinding)
                            .keyboardType(.numberPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maximum")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                        TextField("e.g. 200", text: maxHeadcountBinding)
                            .keyboardType(.numberPad)
                    }
                }
            }
        }
    }

    private var togglesSection: some View {
        AppSurface {
            VStack(spacing: 14) {
                Toggle(isOn: tastingBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tasting available")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Can clients try the food before booking?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: servingStaffBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Serving staff included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you provide servers for the event?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Divider()

                Toggle(isOn: tablewareBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tableware included")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Do you provide plates, utensils, and glasses?")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)
            }
        }
    }

    private var menuSectionsSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Menu")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Button("Add section", systemImage: "plus") {
                        addMenuSection()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.accent)
                }

                if details.menuSections.isEmpty {
                    Text("Add menu sections to showcase your offerings")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                } else {
                    ForEach(Array(details.menuSections.enumerated()), id: \.element.id) { index, section in
                        menuSectionRow(section: section, index: index)
                    }
                }
            }
        }
    }

    private func menuSectionRow(section: MenuSection, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if index > 0 { Divider() }

            HStack {
                TextField("Section name (e.g. Mains)", text: menuSectionTitleBinding(index: index))
                    .font(.subheadline.weight(.semibold))

                Button(role: .destructive) {
                    removeMenuSection(at: index)
                } label: {
                    Image(systemName: "trash")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(section.items.enumerated()), id: \.element.id) { itemIndex, _ in
                HStack(spacing: 8) {
                    TextField("Item name", text: menuItemNameBinding(sectionIndex: index, itemIndex: itemIndex))
                        .font(.subheadline)

                    Button(role: .destructive) {
                        removeMenuItem(sectionIndex: index, itemIndex: itemIndex)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Add item", systemImage: "plus") {
                addMenuItem(to: index)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(AppTheme.Palette.accent)
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

    private var details: CateringDetails {
        if case .catering(let d) = store.draft.categoryDetails { return d }
        return CateringDetails()
    }

    private func updateDetails(_ details: CateringDetails) {
        store.draft.categoryDetails = .catering(details)
    }

    // MARK: - Menu Mutations

    private func addMenuSection() {
        var d = details
        d.menuSections.append(MenuSection())
        updateDetails(d)
    }

    private func removeMenuSection(at index: Int) {
        var d = details
        guard d.menuSections.indices.contains(index) else { return }
        d.menuSections.remove(at: index)
        updateDetails(d)
    }

    private func addMenuItem(to sectionIndex: Int) {
        var d = details
        guard d.menuSections.indices.contains(sectionIndex) else { return }
        d.menuSections[sectionIndex].items.append(MenuItem())
        updateDetails(d)
    }

    private func removeMenuItem(sectionIndex: Int, itemIndex: Int) {
        var d = details
        guard d.menuSections.indices.contains(sectionIndex),
              d.menuSections[sectionIndex].items.indices.contains(itemIndex) else { return }
        d.menuSections[sectionIndex].items.remove(at: itemIndex)
        updateDetails(d)
    }

    // MARK: - Bindings

    private var cuisineBinding: Binding<[String]> {
        Binding(
            get: { details.cuisineTypes },
            set: { var d = details; d.cuisineTypes = $0; updateDetails(d) }
        )
    }

    private var serviceStylesBinding: Binding<[String]> {
        Binding(
            get: { details.serviceStyles },
            set: { var d = details; d.serviceStyles = $0; updateDetails(d) }
        )
    }

    private var dietaryBinding: Binding<[String]> {
        Binding(
            get: { details.dietaryAccommodations },
            set: { var d = details; d.dietaryAccommodations = $0; updateDetails(d) }
        )
    }

    private var minHeadcountBinding: Binding<String> {
        Binding(
            get: { if let v = details.minimumHeadcount { String(v) } else { "" } },
            set: { var d = details; d.minimumHeadcount = Int($0); updateDetails(d) }
        )
    }

    private var maxHeadcountBinding: Binding<String> {
        Binding(
            get: { if let v = details.maximumHeadcount { String(v) } else { "" } },
            set: { var d = details; d.maximumHeadcount = Int($0); updateDetails(d) }
        )
    }

    private var tastingBinding: Binding<Bool> {
        Binding(
            get: { details.tastingAvailable },
            set: { var d = details; d.tastingAvailable = $0; updateDetails(d) }
        )
    }

    private var servingStaffBinding: Binding<Bool> {
        Binding(
            get: { details.servingStaffIncluded },
            set: { var d = details; d.servingStaffIncluded = $0; updateDetails(d) }
        )
    }

    private var tablewareBinding: Binding<Bool> {
        Binding(
            get: { details.tablewareIncluded },
            set: { var d = details; d.tablewareIncluded = $0; updateDetails(d) }
        )
    }

    private func menuSectionTitleBinding(index: Int) -> Binding<String> {
        Binding(
            get: {
                guard details.menuSections.indices.contains(index) else { return "" }
                return details.menuSections[index].title
            },
            set: {
                var d = details
                guard d.menuSections.indices.contains(index) else { return }
                d.menuSections[index].title = $0
                updateDetails(d)
            }
        )
    }

    private func menuItemNameBinding(sectionIndex: Int, itemIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard details.menuSections.indices.contains(sectionIndex),
                      details.menuSections[sectionIndex].items.indices.contains(itemIndex) else { return "" }
                return details.menuSections[sectionIndex].items[itemIndex].name
            },
            set: {
                var d = details
                guard d.menuSections.indices.contains(sectionIndex),
                      d.menuSections[sectionIndex].items.indices.contains(itemIndex) else { return }
                d.menuSections[sectionIndex].items[itemIndex].name = $0
                updateDetails(d)
            }
        )
    }
}
