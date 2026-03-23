import SwiftUI

struct PricingEditView: View {
    let store: VendorProfileEditStore

    @State private var servicesText = ""
    @State private var showTierOverridePicker = false

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        sectionHeader(
                            title: "How do you price?",
                            subtitle: "Choose the clearest way hosts should understand your pricing."
                        )

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                            ],
                            spacing: 12
                        ) {
                            ForEach(PricingModel.allCases) { model in
                                Button {
                                    store.draft.pricingModel = model
                                } label: {
                                    PricingModelCard(
                                        model: model,
                                        isSelected: store.draft.pricingModel == model
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                AppSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        sectionHeader(
                            title: store.draft.pricingModel.title,
                            subtitle: store.draft.pricingModel.subtitle
                        )

                        switch store.draft.pricingModel {
                        case .startingFrom:
                            StartingFromPriceInput(basePriceCents: $store.draft.basePriceCents)
                        case .perEvent:
                            PerEventPriceInput(basePriceCents: $store.draft.basePriceCents)
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
                        case .custom:
                            CustomPricingInput(
                                serviceItems: $store.draft.serviceItems,
                                derivedRangeLabel: store.draft.displayPriceLabel
                            )
                        }
                    }
                }

                if let derivedPriceTier = store.draft.derivedPriceTier {
                    AppSurface {
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader(
                                title: "Discovery tier",
                                subtitle: "This helps hosts interpret your price position for \(store.draft.category.singularTitle.lowercased())."
                            )

                            Text(
                                "Based on your pricing, you'll appear as \(derivedPriceTier.title) (\(store.draft.category.priceRangeLabel(for: derivedPriceTier)) for \(store.draft.category.singularTitle.lowercased()))."
                            )
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)

                            if let overrideTier = store.draft.priceTierOverride {
                                Text("Override active: \(overrideTier.title) will be used instead of the automatic tier.")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }

                            HStack(spacing: 12) {
                                Button(showTierOverridePicker ? "Hide tier options" : "Change tier") {
                                    withAnimation(.snappy) {
                                        showTierOverridePicker.toggle()
                                    }
                                }
                                .buttonStyle(SecondaryActionButtonStyle())

                                if store.draft.priceTierOverride != nil {
                                    Button("Reset to auto") {
                                        withAnimation(.snappy) {
                                            store.draft.priceTierOverride = nil
                                            showTierOverridePicker = false
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                                }
                            }

                            if showTierOverridePicker || store.draft.priceTierOverride != nil {
                                VStack(spacing: 10) {
                                    ForEach(PriceTier.allCases) { tier in
                                        Button {
                                            store.draft.priceTierOverride = tier
                                        } label: {
                                            TierOverrideOptionCard(
                                                tier: tier,
                                                category: store.draft.category,
                                                isSelected: store.draft.priceTierOverride == tier
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                }

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

                AppSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        sectionHeader(
                            title: "Key services",
                            subtitle: "Use broad terms hosts would naturally search for."
                        )

                        TextField("Floral installs, tablescapes, candles", text: $servicesText, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .textInputAutocapitalization(.words)
                    }
                }

                Button(store.loadingState.isLoading ? "Saving..." : "Save pricing") {
                    store.draft.services = servicesText
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    store.draft.serviceItems = store.draft.preparedServiceItems

                    Task {
                        await store.save()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(store.loadingState.isLoading)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackdrop())
        .navigationTitle("Services & Pricing")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: store.draft.pricingModel)
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Pricing saved") {
            store.lastSaveOutcome = .idle
        }
        .onAppear {
            servicesText = store.draft.services.joined(separator: ", ")
            showTierOverridePicker = store.draft.priceTierOverride != nil
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

private struct PricingModelCard: View {
    let model: PricingModel
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: model.symbolName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isSelected ? AppTheme.Palette.elevatedSurface : AppTheme.Palette.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? AppTheme.Palette.elevatedSurface : AppTheme.Palette.textPrimary)

                Text(model.subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(isSelected ? AppTheme.Palette.elevatedSurface.opacity(0.82) : AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(backgroundStyle, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                .stroke(isSelected ? AppTheme.Palette.accent : AppTheme.Palette.border, lineWidth: 1)
        }
    }

    private var backgroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.Palette.accent)
        }

        return AnyShapeStyle(AppTheme.Palette.elevatedSurface)
    }
}

private struct StartingFromPriceInput: View {
    @Binding var basePriceCents: Int?

    var body: some View {
        CurrencyField(
            title: "What's your starting price?",
            prompt: "3500",
            cents: $basePriceCents
        )
    }
}

private struct PerEventPriceInput: View {
    @Binding var basePriceCents: Int?

    var body: some View {
        CurrencyField(
            title: "What do you charge per event?",
            prompt: "2500",
            cents: $basePriceCents
        )
    }
}

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

private struct CustomPricingInput: View {
    @Binding var serviceItems: [VendorServiceItem]
    let derivedRangeLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if serviceItems.isEmpty {
                Text("Add named services and prices so hosts can understand your range at a glance.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            ForEach(serviceItems.indices, id: \.self) { index in
                ServiceItemEditor(
                    item: $serviceItems[index],
                    canMoveUp: index > 0,
                    canMoveDown: index < serviceItems.count - 1,
                    moveUp: { moveItem(from: index, to: index - 1) },
                    moveDown: { moveItem(from: index, to: index + 1) },
                    delete: { serviceItems.remove(at: index) }
                )
            }

            Button("Add service") {
                serviceItems.append(
                    VendorServiceItem(
                        title: "",
                        priceCents: 0,
                        description: "",
                        displayOrder: serviceItems.count
                    )
                )
            }
            .buttonStyle(SecondaryActionButtonStyle())

            if let derivedRangeLabel {
                Text("Current range: \(derivedRangeLabel)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }

    private func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard serviceItems.indices.contains(sourceIndex),
              serviceItems.indices.contains(destinationIndex) else {
            return
        }

        withAnimation(.snappy) {
            let item = serviceItems.remove(at: sourceIndex)
            serviceItems.insert(item, at: destinationIndex)
            serviceItems = serviceItems.enumerated().map { index, item in
                VendorServiceItem(
                    id: item.id,
                    title: item.title,
                    priceCents: item.priceCents,
                    description: item.description,
                    displayOrder: index
                )
            }
        }
    }
}

private struct ServiceItemEditor: View {
    @Binding var item: VendorServiceItem

    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Service name", text: $item.title)
                        .textInputAutocapitalization(.words)

                    CurrencyField(
                        title: "Price",
                        prompt: "150",
                        cents: itemPriceBinding,
                        isCompact: true
                    )

                    TextField("Optional description", text: $item.description, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
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
        }
        .padding(16)
        .background(AppTheme.Palette.inputFill, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                .stroke(AppTheme.Palette.border, lineWidth: 1)
        }
    }

    private var itemPriceBinding: Binding<Int?> {
        Binding(
            get: { item.priceCents > 0 ? item.priceCents : nil },
            set: { item = VendorServiceItem(
                id: item.id,
                title: item.title,
                priceCents: $0 ?? 0,
                description: item.description,
                displayOrder: item.displayOrder
            ) }
        )
    }
}

private struct TierOverrideOptionCard: View {
    let tier: PriceTier
    let category: VendorCategory
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? AppTheme.Palette.elevatedSurface : AppTheme.Palette.textPrimary)

                    Text(tier.signal)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(isSelected ? AppTheme.Palette.elevatedSurface.opacity(0.82) : AppTheme.Palette.textSecondary)
                }

                Spacer()

                Text(category.priceRangeLabel(for: tier))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? AppTheme.Palette.elevatedSurface : AppTheme.Palette.textPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                .stroke(isSelected ? AppTheme.Palette.accent : AppTheme.Palette.border, lineWidth: 1)
        }
    }

    private var backgroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.Palette.accent)
        }

        return AnyShapeStyle(AppTheme.Palette.elevatedSurface)
    }
}

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
