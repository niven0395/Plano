import SwiftUI
#if canImport(TipKit)
import TipKit
#endif

struct CategoryBrowseView: View {
    @State private var store: CategoryBrowseStore

    @Environment(AppRouter.self) private var router
    @State private var showsFilters = false

    init(category: VendorCategory, planner: HostPlanningStore, availabilityService: any VendorAvailabilityServiceProtocol) {
        _store = State(initialValue: CategoryBrowseStore(
            category: category,
            planner: planner,
            availabilityService: availabilityService
        ))
    }

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: store.category.title)

                VStack(alignment: .leading, spacing: 12) {
                    BrowseSearchField(
                        query: $store.searchQuery,
                        filterCount: store.filterState.activeFilterCount,
                        hasActiveFilters: store.filterState.hasActiveFilters,
                        showsFilters: showsFilters,
                        onFilterTap: toggleFilters
                    )

                    if showsFilters {
                        BrowseFilterContent(store: store)
                    }
                }
                .animation(.snappy(duration: 0.2), value: showsFilters)

                if store.category == .photographer {
                    PhotoVideoTabBar(selectedTab: $store.photoVideoTab)
                }

                BrowseResultsSection(store: store)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle(store.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .hapticFeedback(.selection, trigger: showsFilters)
        .onChange(of: store.filterState.selectedCity) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.ratingFilter) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.sortMode) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.availabilityDate) { _, _ in Task { await store.refreshAvailability() } }
        .onChange(of: store.filterState.selectedMultiChoice) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.selectedToggles) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.guestCount) { _, _ in store.applyFilters() }
        .onChange(of: store.photoVideoTab) { _, _ in store.applyFilters() }
        .task {
            await store.loadIfNeeded()
        }
    }

    private func toggleFilters() {
        withAnimation(.snappy(duration: 0.2)) {
            showsFilters.toggle()
        }
    }
}

// MARK: - Filter Content

private struct BrowseFilterContent: View {
    @Bindable var store: CategoryBrowseStore

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Filters", systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    if store.filterState.hasActiveFilters {
                        Button("Reset") {
                            store.resetFilters()
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.accent)
                    }
                }

                CommonBrowseFilters(
                    filterState: $store.filterState,
                    availableCities: store.availableCities
                )

                CategoryFilterSection(
                    category: store.category,
                    filterState: $store.filterState
                )
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Results Section

private struct BrowseResultsSection: View {
    let store: CategoryBrowseStore
    private let shortlistTip = SearchRankingTip()

    var body: some View {
        switch store.presentationState {
        case .live:
            if store.visibleResults.isEmpty {
                EmptyStateCard(
                    symbolName: "sparkle.magnifyingglass",
                    title: "No \(store.category.title.lowercased()) match",
                    message: store.searchQuery.isEmpty
                        ? "Adjust your filters to see more vendors in this category."
                        : "Try a different search term or adjust your filters."
                )
            } else {
                Text("\(store.vendorCount) \(store.category.title.lowercased())")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                LazyVStack(spacing: 16) {
                    ForEach(Array(store.displayedResults.enumerated()), id: \.element.id) { index, result in
                        ZStack(alignment: .topTrailing) {
                            NavigationLink(value: DiscoveryRoute.vendorProfile(result.vendor.id)) {
                                CategoryBrowseResultCard(result: result)
                            }
                            .buttonStyle(.plain)

                            Button(
                                store.isSaved(result.vendor.id)
                                    ? "Remove from shortlist"
                                    : "Save to shortlist",
                                systemImage: store.isSaved(result.vendor.id) ? "heart.fill" : "heart"
                            ) {
                                store.toggleSaved(result.vendor.id)
                            }
                            .labelStyle(.iconOnly)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(
                                store.isSaved(result.vendor.id)
                                    ? AppTheme.toneColor(.coral)
                                    : .white
                            )
                            .accessibilityLabel(
                                store.isSaved(result.vendor.id)
                                    ? "Remove from shortlist"
                                    : "Add to shortlist"
                            )
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial.opacity(0.6), in: Circle())
                            .buttonStyle(.plain)
                            .disabled(store.isSavePending(result.vendor.id))
                            .opacity(store.isSavePending(result.vendor.id) ? 0.55 : 1)
                            .popoverTip(index == 0 ? shortlistTip : nil)
                            .padding(12)
                        }
                    }

                    if store.canLoadMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .onAppear { store.loadMore() }
                    }
                }
                .animation(.smooth(duration: 0.25), value: store.displayedResults.map(\.id))
            }

        case .loading:
            LazyVStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    CategoryBrowseResultCardSkeleton()
                }
            }

        case .error(let message):
            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Unable to load \(store.category.title.lowercased())")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    Button("Try again") {
                        Task { await store.retry() }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}

// MARK: - Search Field

private struct BrowseSearchField: View {
    @Binding var query: String
    let filterCount: Int
    let hasActiveFilters: Bool
    let showsFilters: Bool
    let onFilterTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.Palette.subdued)

            TextField("Search by name, style, or tag", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button(action: onFilterTap) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: showsFilters
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                    )
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(
                        hasActiveFilters || showsFilters
                            ? AppTheme.Palette.accent
                            : AppTheme.Palette.subdued
                    )

                    if filterCount > 0 {
                        Text("\(filterCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.Palette.accent, in: Capsule())
                            .offset(x: 8, y: -6)
                    }
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showsFilters ? "Hide filters" : "Show filters")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.Palette.inputFill, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
    }
}

// MARK: - Photo & Video Tab Bar

enum PhotoVideoTab: String, CaseIterable, Identifiable {
    case photos
    case video

    var id: Self { self }

    var title: String {
        switch self {
        case .photos: "Photos"
        case .video: "Video"
        }
    }
}

private struct PhotoVideoTabBar: View {
    @Binding var selectedTab: PhotoVideoTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PhotoVideoTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedTab == tab ? .white : AppTheme.Palette.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab ? AppTheme.Palette.accent : AppTheme.Palette.inputFill,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
