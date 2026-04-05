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
                    store.availabilityDate != nil {
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

            AvailabilityDateChip(
                date: Binding(
                    get: { store.availabilityDate },
                    set: { store.availabilityDate = $0 }
                )
            )
        }
    }
}
