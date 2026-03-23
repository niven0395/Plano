import SwiftUI

struct SearchBarView: View {
    @Bindable var store: SearchStore
    var showsFilters: Bool
    var toggleFilters: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: showsFilters ? 18 : 10) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.Palette.subdued)

                TextField("Try 'photography' or 'caterers'", text: $store.query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onSubmit { store.commitCurrentSearch() }

                Button(action: toggleFilters) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: showsFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(
                                store.activeRefinementCount > 0 || showsFilters
                                    ? AppTheme.Palette.accent
                                    : AppTheme.Palette.subdued
                            )

                        if store.activeRefinementCount > 0 {
                            Text("\(store.activeRefinementCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppTheme.Palette.accent, in: Capsule())
                                .offset(x: 10, y: -8)
                        }
                    }
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsFilters ? "Hide filters" : "Show filters")

                if !store.query.isEmpty ||
                    store.selectedCategory != nil ||
                    store.selectedPriceTier != nil ||
                    store.selectedAvailability != .all ||
                    store.ratingFilter != .all {
                    Button("Clear", action: store.clearFilters)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.Palette.inputFill, in: .rect(cornerRadius: AppTheme.smallCornerRadius))

            if showsFilters {
                SearchControlsView(store: store)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if !store.activeFilterSummary.isEmpty {
                Text(store.activeFilterSummary)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
        .animation(.snappy(duration: 0.2), value: showsFilters)
    }
}

private struct SearchControlsView: View {
    @Bindable var store: SearchStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Refine search", systemImage: "slider.horizontal.3")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Price level")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(PriceTier.allCases) { tier in
                            Button {
                                store.selectedPriceTier = store.selectedPriceTier == tier ? nil : tier
                            } label: {
                                FilterChip(title: tier.title, isSelected: store.selectedPriceTier == tier)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if store.hasEventContext {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Availability")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(VendorAvailabilityFilter.allCases) { filter in
                                Button {
                                    store.selectedAvailability = filter
                                } label: {
                                    FilterChip(title: filter.title, isSelected: store.selectedAvailability == filter)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            HStack(spacing: 12) {
                Picker("Rating", selection: $store.ratingFilter) {
                    ForEach(SearchRatingFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker("Sort", selection: $store.sortMode) {
                    ForEach(SearchSortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Palette.textPrimary)
        }
    }
}
