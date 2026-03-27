import SwiftUI

struct CategoryBrowseView: View {
    let store: CategoryBrowseStore

    @Environment(AppRouter.self) private var router
    @State private var showsFilters = false

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BrowseSearchField(query: $store.searchQuery)

                if store.category == .photographer {
                    PhotoVideoTabBar(selectedTab: $store.photoVideoTab)
                }

                BrowseFilterBar(
                    store: store,
                    showsFilters: showsFilters,
                    toggleFilters: toggleFilters
                )

                BrowseResultsSection(store: store)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle(store.category.title)
        .navigationBarTitleDisplayMode(.large)
        .hapticFeedback(.selection, trigger: showsFilters)
        .task {
            await store.load()
        }
    }

    private func toggleFilters() {
        withAnimation(.snappy(duration: 0.2)) {
            showsFilters.toggle()
        }
    }
}

// MARK: - Filter Bar

private struct BrowseFilterBar: View {
    let store: CategoryBrowseStore
    let showsFilters: Bool
    let toggleFilters: () -> Void

    var body: some View {
        @Bindable var store = store

        AppSurface {
            VStack(alignment: .leading, spacing: showsFilters ? 18 : 10) {
                HStack(spacing: 12) {
                    Label("Filters", systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Button(action: toggleFilters) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: showsFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                            )
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(
                                store.filterState.hasActiveFilters || showsFilters
                                    ? AppTheme.Palette.accent
                                    : AppTheme.Palette.subdued
                            )

                            if store.filterState.activeFilterCount > 0 {
                                Text("\(store.filterState.activeFilterCount)")
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

                    if store.filterState.hasActiveFilters {
                        Button("Reset") {
                            store.resetFilters()
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.accent)
                    }
                }

                if showsFilters {
                    VStack(alignment: .leading, spacing: 20) {
                        CommonBrowseFilters(
                            filterState: $store.filterState,
                            availableCities: store.availableCities,
                            showsAvailability: store.hasEventContext
                        )

                        CategoryFilterSection(
                            category: store.category,
                            filterState: $store.filterState
                        )
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.2), value: showsFilters)
        }
        .onChange(of: store.filterState.selectedCity) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.ratingFilter) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.sortMode) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.availabilityFilter) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.selectedMultiChoice) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.selectedToggles) { _, _ in store.applyFilters() }
        .onChange(of: store.filterState.guestCount) { _, _ in store.applyFilters() }
        .onChange(of: store.photoVideoTab) { _, _ in store.applyFilters() }
    }
}

// MARK: - Results Section

private struct BrowseResultsSection: View {
    let store: CategoryBrowseStore

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
                    ForEach(store.displayedResults) { result in
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
                                    : AppTheme.Palette.textPrimary
                            )
                            .accessibilityLabel(
                                store.isSaved(result.vendor.id)
                                    ? "Remove from shortlist"
                                    : "Add to shortlist"
                            )
                            .frame(width: 38, height: 38)
                            .background(AppTheme.Palette.elevatedSurface, in: Circle())
                            .buttonStyle(.plain)
                            .disabled(store.isSavePending(result.vendor.id))
                            .opacity(store.isSavePending(result.vendor.id) ? 0.55 : 1)
                            .padding(16)
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
