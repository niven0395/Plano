import PhotosUI
import SwiftUI

struct PricingEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss
    @State private var isPackagesExpanded = false
    @State private var isAddOnsExpanded = false
    @State private var isPriceSheetExpanded = false

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Visibility

                AppSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        sectionHeader(
                            title: "Pricing visibility",
                            subtitle: "Control whether hosts see your pricing immediately or need to ask."
                        )

                        Picker("Pricing visibility", selection: $store.draft.pricingVisibility) {
                            ForEach(PricingVisibility.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // MARK: - Base Price

                AppSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        sectionHeader(
                            title: "Your starting price",
                            subtitle: "This is the price hosts see when browsing. Pick how you charge."
                        )

                        PricingModelPicker(selection: $store.draft.pricingModel)

                        switch store.draft.pricingModel {
                        case .perEvent:
                            CurrencyField(
                                title: "What do you charge per event?",
                                prompt: "2500",
                                cents: $store.draft.basePriceCents
                            )
                        case .perHour:
                            PerHourPriceInput(
                                hourlyRateCents: $store.draft.hourlyRateCents,
                                minimumHours: $store.draft.minimumHours
                            )
                        case .perPerson:
                            PerPersonPriceInput(
                                perPersonPriceCents: $store.draft.perPersonPriceCents,
                                minimumGuests: $store.draft.minimumGuests
                            )
                        default:
                            EmptyView()
                        }

                        if let displayLabel = store.draft.displayPriceLabel {
                            Text("Hosts will see: **\(displayLabel)**")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }
                }

                // MARK: - Pricing Details

                sectionHeader(
                    title: "Pricing details",
                    subtitle: "Optional — add packages, add-ons, or a price sheet to help hosts understand your full offering."
                )
                .padding(.horizontal, 4)

                // Price Sheet Images
                PriceSheetSection(store: store, isExpanded: $isPriceSheetExpanded)

                // Packages
                PackagesSection(packages: $store.draft.packages, isExpanded: $isPackagesExpanded)

                // Add-ons
                AddOnsSection(addOns: $store.draft.addOns, isExpanded: $isAddOnsExpanded)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
        .background(AppBackdrop())
        .navigationTitle("Pricing")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: store.draft.pricingModel)
        .safeAreaInset(edge: .bottom) {
            VendorProfileEditSaveBar(
                store: store,
                buttonLabel: "Save pricing",
                beforeSave: {
                    store.draft.serviceItems = store.draft.preparedServiceItems
                }
            )
        }
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Pricing saved") {
            store.lastSaveOutcome = .idle
        }
        .onAppear {
            isPackagesExpanded = !store.draft.packages.isEmpty
            isAddOnsExpanded = !store.draft.addOns.isEmpty
            isPriceSheetExpanded = !store.draft.pricingImagePaths.isEmpty
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text(subtitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
    }
}

// MARK: - Pricing Model Picker

private struct PricingModelPicker: View {
    @Binding var selection: PricingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How do you charge?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            ForEach(PricingModel.allCases.filter({ $0 != .startingFrom && $0 != .custom })) { model in
                Button {
                    selection = selection == model ? .startingFrom : model
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: model.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 24)
                            .foregroundStyle(selection == model ? AppTheme.Palette.accent : AppTheme.Palette.textSecondary)

                        Text(model.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Spacer()

                        if selection == model {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.accent)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        selection == model ? AppTheme.Palette.accent.opacity(0.08) : AppTheme.Palette.inputFill,
                        in: .rect(cornerRadius: AppTheme.smallCornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                            .stroke(selection == model ? AppTheme.Palette.accent : AppTheme.Palette.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Packages Section

private struct PackagesSection: View {
    @Binding var packages: [VendorPackage]
    @Binding var isExpanded: Bool

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    withAnimation(.snappy) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Label("Packages", systemImage: "shippingbox")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !packages.isEmpty && !isExpanded {
                    Text("\(packages.count) package\(packages.count == 1 ? "" : "s") configured")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                if isExpanded {
                    Text("Create tiered offerings — like Starter, Standard, and Premium.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    ForEach(packages.indices, id: \.self) { index in
                        PackageEditor(
                            package: $packages[index],
                            canMoveUp: index > 0,
                            canMoveDown: index < packages.count - 1,
                            moveUp: { movePackage(from: index, to: index - 1) },
                            moveDown: { movePackage(from: index, to: index + 1) },
                            delete: { packages.remove(at: index) }
                        )
                    }

                    Button("Add package") {
                        packages.append(
                            VendorPackage(displayOrder: packages.count)
                        )
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    private func movePackage(from sourceIndex: Int, to destinationIndex: Int) {
        guard packages.indices.contains(sourceIndex),
              packages.indices.contains(destinationIndex) else { return }

        withAnimation(.snappy) {
            let item = packages.remove(at: sourceIndex)
            packages.insert(item, at: destinationIndex)
        }
    }
}

// MARK: - Package Editor

private struct PackageEditor: View {
    @Binding var package: VendorPackage

    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void

    @State private var newIncludedItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Package name", text: $package.title)
                        .textInputAutocapitalization(.words)
                        .font(.subheadline.weight(.semibold))

                    CurrencyField(
                        title: "Price",
                        prompt: "2500",
                        cents: packagePriceBinding,
                        isCompact: true
                    )

                    TextField("Description (optional)", text: $package.description, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                        .font(.subheadline)
                }

                VStack(spacing: 10) {
                    Button(action: moveUp) {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveUp)
                    .opacity(canMoveUp ? 1 : 0.35)

                    Button(action: moveDown) {
                        Image(systemName: "arrow.down")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveDown)
                    .opacity(canMoveDown ? 1 : 0.35)

                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            // Included items
            VStack(alignment: .leading, spacing: 8) {
                Text("What's included")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                ForEach(package.includedItems.indices, id: \.self) { itemIndex in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.accent)

                        Text(package.includedItems[itemIndex])
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Spacer()

                        Button {
                            package.includedItems.remove(at: itemIndex)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Palette.textSecondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Add item...", text: $newIncludedItem)
                        .font(.subheadline)
                        .onSubmit { addIncludedItem() }

                    if !newIncludedItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            addIncludedItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.Palette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Highlight toggle
            Toggle("Mark as popular", isOn: $package.isHighlighted)
                .font(.subheadline)
                .tint(AppTheme.Palette.accent)
        }
        .padding(16)
        .background(AppTheme.Palette.inputFill, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                .stroke(package.isHighlighted ? AppTheme.Palette.accent : AppTheme.Palette.border, lineWidth: 1)
        }
    }

    private var packagePriceBinding: Binding<Int?> {
        Binding(
            get: { package.priceCents > 0 ? package.priceCents : nil },
            set: { package.priceCents = $0 ?? 0 }
        )
    }

    private func addIncludedItem() {
        let trimmed = newIncludedItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        package.includedItems.append(trimmed)
        newIncludedItem = ""
    }
}

// MARK: - Add-ons Section

private struct AddOnsSection: View {
    @Binding var addOns: [VendorAddOn]
    @Binding var isExpanded: Bool

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    withAnimation(.snappy) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Label("Add-ons", systemImage: "plus.rectangle.on.rectangle")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !addOns.isEmpty && !isExpanded {
                    Text("\(addOns.count) add-on\(addOns.count == 1 ? "" : "s") configured")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                if isExpanded {
                    Text("Optional extras hosts can add — like a second shooter, drone coverage, or late-night snacks.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    ForEach(addOns.indices, id: \.self) { index in
                        AddOnEditor(
                            addOn: $addOns[index],
                            delete: { addOns.remove(at: index) }
                        )
                    }

                    Button("Add add-on") {
                        addOns.append(
                            VendorAddOn(displayOrder: addOns.count)
                        )
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}

// MARK: - Add-on Editor

private struct AddOnEditor: View {
    @Binding var addOn: VendorAddOn
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Add-on name", text: $addOn.title)
                    .textInputAutocapitalization(.words)
                    .font(.subheadline.weight(.semibold))

                CurrencyField(
                    title: "Price",
                    prompt: "300",
                    cents: addOnPriceBinding,
                    isCompact: true
                )

                TextField("Brief description (optional)", text: $addOn.description)
                    .font(.subheadline)
            }

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppTheme.Palette.inputFill, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                .stroke(AppTheme.Palette.border, lineWidth: 1)
        }
    }

    private var addOnPriceBinding: Binding<Int?> {
        Binding(
            get: { addOn.priceCents > 0 ? addOn.priceCents : nil },
            set: { addOn.priceCents = $0 ?? 0 }
        )
    }
}

// MARK: - Price Sheet Section

// MARK: - Price Sheet Section

private struct PriceSheetSection: View {
    let store: VendorProfileEditStore
    @Binding var isExpanded: Bool
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    withAnimation(.snappy) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Label("Price sheet", systemImage: "doc.richtext")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !store.draft.pricingImagePaths.isEmpty && !isExpanded {
                    Text("\(store.draft.pricingImagePaths.count) image\(store.draft.pricingImagePaths.count == 1 ? "" : "s") uploaded")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                if isExpanded {
                    Text("Upload a photo of your rate card or detailed pricing menu.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    if !store.draft.pricingImagePaths.isEmpty {
                        ForEach(Array(store.draft.pricingImagePaths.enumerated()), id: \.offset) { index, path in
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(AppTheme.Palette.accent)
                                Text("Price sheet \(index + 1)")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Palette.textPrimary)
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await store.removePricingImage(at: index) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Palette.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(AppTheme.Palette.inputFill, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
                        }
                    }

                    if store.draft.pricingImagePaths.count < 3 {
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images
                        ) {
                            Label("Upload image", systemImage: "photo.badge.plus")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .onChange(of: selectedPhoto) { _, newValue in
                            guard let newValue else { return }
                            Task {
                                if let data = try? await newValue.loadTransferable(type: Data.self) {
                                    await store.addPricingImage(data: data)
                                }
                                selectedPhoto = nil
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Per Hour Input

private struct PerHourPriceInput: View {
    @Binding var hourlyRateCents: Int?
    @Binding var minimumHours: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CurrencyField(
                title: "What's your hourly rate?",
                prompt: "150",
                cents: $hourlyRateCents
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Minimum hours")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Text("\(max(minimumHours ?? 1, 1)) hr")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Stepper(value: minimumHoursValue, in: 1 ... 12) {
                    Text("Set the minimum booking length")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }

            if let hourlyRateCents, hourlyRateCents > 0 {
                let minimumHours = max(self.minimumHours ?? 1, 1)
                Text("\(minimumHours) hours x \(currencyLabel(forCents: hourlyRateCents)) = \(currencyLabel(forCents: hourlyRateCents * minimumHours)) minimum")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }

    private var minimumHoursValue: Binding<Int> {
        Binding(
            get: { max(minimumHours ?? 1, 1) },
            set: { minimumHours = $0 }
        )
    }
}

// MARK: - Per Person Input

private struct PerPersonPriceInput: View {
    @Binding var perPersonPriceCents: Int?
    @Binding var minimumGuests: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CurrencyField(
                title: "What's your per-person price?",
                prompt: "45",
                cents: $perPersonPriceCents
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Minimum guests")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Text("\(max(minimumGuests ?? 1, 1)) guests")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Stepper(value: minimumGuestsValue, in: 1 ... 200) {
                    Text("Set the minimum guest count")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }

            if let perPersonPriceCents, perPersonPriceCents > 0 {
                let minimumGuests = max(self.minimumGuests ?? 1, 1)
                Text("\(minimumGuests) guests x \(currencyLabel(forCents: perPersonPriceCents)) = \(currencyLabel(forCents: perPersonPriceCents * minimumGuests)) minimum")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }

    private var minimumGuestsValue: Binding<Int> {
        Binding(
            get: { max(minimumGuests ?? 1, 1) },
            set: { minimumGuests = $0 }
        )
    }
}

// MARK: - Currency Field

private struct CurrencyField: View {
    let title: String
    let prompt: String
    @Binding var cents: Int?
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            HStack(spacing: 12) {
                Text("$")
                    .font(isCompact ? .headline : .title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                TextField(prompt, text: dollarBinding)
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, isCompact ? 12 : 14)
            .background(AppTheme.Palette.inputFill, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                    .stroke(AppTheme.Palette.border, lineWidth: 1)
            }
        }
    }

    private var dollarBinding: Binding<String> {
        Binding(
            get: {
                guard let cents else { return "" }
                return String(max(cents / 100, 0))
            },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)
                guard !digits.isEmpty, let dollars = Int(digits) else {
                    cents = nil
                    return
                }

                cents = dollars * 100
            }
        )
    }
}

private func currencyLabel(forCents cents: Int) -> String {
    "$\(max(Int((Double(cents) / 100).rounded()), 0).formatted())"
}
