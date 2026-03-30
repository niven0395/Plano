import SwiftUI

struct SearchView: View {
    let store: SearchStore

    @Environment(HostPlanningStore.self) private var planner
    @State private var showsFilters = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SearchBarView(
                    store: store,
                    showsFilters: showsFilters,
                    toggleFilters: toggleFilters
                )

                Group {
                    if store.isShowingDiscoveryState {
                        SearchDiscoveryState(store: store)
                    } else {
                        SearchResultState(store: store)
                    }
                }
                .animation(.easeOut(duration: 0.3), value: store.presentationState)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .hapticFeedback(.selection, trigger: showsFilters)
        .hapticFeedback(.selection, trigger: store.filterChangeCounter)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await planner.loadIfNeeded()
            await store.loadIfNeeded()
        }
        .onChange(of: planner.selectedEventID) { _, _ in
            store.syncToSelectedEvent()
            showsFilters = false
        }
    }

    private func toggleFilters() {
        withAnimation(.snappy(duration: 0.2)) {
            showsFilters.toggle()
        }
    }

}

struct SearchDiscoveryState: View {
    let store: SearchStore

    var body: some View {
        switch store.presentationState {
        case .live:
            SectionHeader(
                title: "Suggested searches",
                subtitle: store.hasEventContext
                    ? "Contextual shortcuts for when you know the need, not the business name."
                    : "Quick ways to jump into discovery when you know the kind of vendor you need."
            )

            AppSurface {
                VStack(spacing: 10) {
                    ForEach(store.suggestedSearchCategories, id: \.self) { category in
                        Button {
                            store.applySuggestedSearch(for: category)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: category.symbolName)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.toneColor(category.accentTone))
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.suggestedSearchText(for: category))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.Palette.textPrimary)
                                        .multilineTextAlignment(.leading)

                                    Text(category.singularTitle)
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(AppTheme.Palette.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.subdued)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !store.recentQueries.isEmpty {
                SectionHeader(
                    title: "Recent searches",
                    subtitle: "Quick ways back into high-intent discovery paths."
                )

                AppSurface {
                    RecentSearchRow(items: store.recentQueries) { query in
                        store.applyRecentQuery(query)
                    }
                }
            }

        case .loading:
            LazyVStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    CategoryBrowseResultCardSkeleton()
                }
            }

        case .error(let message):
            SearchErrorCard(message: message, retryAction: store.retryPresentation)
        }
    }
}

struct SearchResultState: View {
    let store: SearchStore

    @Environment(HostPlanningStore.self) private var planner

    var body: some View {
        SectionHeader(
            title: "\(store.visibleResults.count) vendors",
            subtitle: store.activeFilterSummary.isEmpty
                ? (store.hasEventContext
                    ? "Ranked for event fit, availability, reviews, response speed, and shortlist context."
                    : "Ranked for reviews, response speed, pricing clarity, and shortlist context.")
                : store.activeFilterSummary
        )

        if !planner.savedVendorIDs.isEmpty {
            AppSurface {
                Label(
                    store.hasEventContext
                        ? "\(planner.savedVendorIDs.count) shortlisted vendors are boosted for this event."
                        : "\(planner.savedVendorIDs.count) shortlisted vendors are boosted in search.",
                    systemImage: "heart.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }

        switch store.presentationState {
        case .live:
            if store.visibleResults.isEmpty {
                EmptyStateCard(
                    symbolName: "sparkle.magnifyingglass",
                    title: "No vendors match this filter set",
                    message: "Reset the price level or loosen the availability and rating filters to reopen the shortlist."
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(Array(store.visibleResults.enumerated()), id: \.element.id) { index, result in
                        ZStack(alignment: .topTrailing) {
                            NavigationLink(value: DiscoveryRoute.vendorProfile(result.vendor.id)) {
                                CategoryBrowseResultCard(result: result, showsCategoryTag: true)
                            }
                            .buttonStyle(.plain)

                            Button(
                                store.isSaved(result.vendor.id) ? "Remove from shortlist" : "Save to shortlist",
                                systemImage: store.isSaved(result.vendor.id) ? "heart.fill" : "heart"
                            ) {
                                store.toggleSaved(result.vendor.id)
                            }
                            .labelStyle(.iconOnly)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(store.isSaved(result.vendor.id) ? AppTheme.toneColor(.coral) : .white)
                            .accessibilityLabel(store.isSaved(result.vendor.id) ? "Remove from shortlist" : "Add to shortlist")
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial.opacity(0.6), in: Circle())
                            .symbolEffect(.bounce, value: store.isSaved(result.vendor.id))
                            .buttonStyle(.plain)
                            .disabled(store.isSavePending(result.vendor.id))
                            .opacity(store.isSavePending(result.vendor.id) ? 0.55 : 1)
                            .padding(12)
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .animation(.smooth(duration: 0.25), value: store.visibleResults.map(\.id))
            }

        case .loading:
            LazyVStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    CategoryBrowseResultCardSkeleton()
                }
            }

        case .error(let message):
            SearchErrorCard(message: message, retryAction: store.retryPresentation)
        }
    }
}

struct SearchErrorCard: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("Search is temporarily unavailable")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Button("Return to results", action: retryAction)
                    .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }
}

struct RecentSearchRow: View {
    let items: [String]
    let action: (String) -> Void
    private let chunkedItems: [[String]]

    init(items: [String], action: @escaping (String) -> Void) {
        self.items = items
        self.action = action
        self.chunkedItems = stride(from: 0, to: items.count, by: 2).map { index in
            Array(items[index..<min(index + 2, items.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(chunkedItems, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Button {
                            action(item)
                        } label: {
                            FilterChip(title: item, isSelected: false)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct FlexibleReasonRow: View {
    let reasons: [SearchRankingReason]
    private let chunkedReasons: [[SearchRankingReason]]

    init(reasons: [SearchRankingReason]) {
        self.reasons = reasons
        self.chunkedReasons = stride(from: 0, to: reasons.count, by: 2).map { index in
            Array(reasons[index..<min(index + 2, reasons.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunkedReasons, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { reason in
                        Text(reason.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.toneColor(reason.tone))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(AppTheme.toneBackground(reason.tone), in: Capsule())
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}
