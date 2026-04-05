import SwiftUI

struct CategoryShortcut: Identifiable, Hashable {
    let category: VendorCategory

    var id: VendorCategory { category }
}

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(SearchStore.self) private var searchStore
    @Environment(HostPlanningStore.self) private var planner

    @AppStorage("plano.home.welcomeDismissed") private var welcomeDismissed = false
    @State private var showsFilters = false

    private var popularCategories: [CategoryShortcut] {
        VendorCategory.homeDisplayOrder.map { CategoryShortcut(category: $0) }
    }

    private var showsWelcomeHero: Bool {
        !planner.hasCompletedOnboarding && !welcomeDismissed
    }

    private var isSearchActive: Bool {
        !searchStore.isShowingDiscoveryState || !searchStore.query.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if showsWelcomeHero {
                    WelcomeHeroCard {
                        withAnimation(.easeOut(duration: 0.25)) {
                            welcomeDismissed = true
                        }
                    }
                }

                SectionHeader(title: "Discover")

                SearchBarView(
                    store: searchStore,
                    showsFilters: showsFilters,
                    toggleFilters: toggleFilters
                )

                if isSearchActive {
                    SearchResultState(store: searchStore)
                        .animation(.easeOut(duration: 0.3), value: searchStore.presentationState)
                } else {
                    HomePopularCategoriesSection(
                        categories: popularCategories,
                        onSelect: openCategorySearch
                    )
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .hapticFeedback(.selection, trigger: showsFilters)
        .hapticFeedback(.selection, trigger: searchStore.filterChangeCounter)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await planner.loadIfNeeded()
            await searchStore.loadIfNeeded()
        }
    }

    private func openCategorySearch(_ category: VendorCategory) {
        router.homePath.append(.categoryBrowse(category))
    }

    private func toggleFilters() {
        withAnimation(.snappy(duration: 0.2)) {
            showsFilters.toggle()
        }
    }
}

// MARK: - Section Views

private struct HomePopularCategoriesSection: View {
    let categories: [CategoryShortcut]
    let onSelect: (VendorCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, shortcut in
                    Button {
                        onSelect(shortcut.category)
                    } label: {
                        CategoryShortcutCard(shortcut: shortcut)
                    }
                    .buttonStyle(CategoryCardButtonStyle())
                    .staggeredAppear(index: index)
                }
            }
        }
    }
}

private struct WelcomeHeroCard: View {
    var onDismiss: () -> Void

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text("Find your perfect vendors")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Button("Dismiss", systemImage: "xmark") {
                        onDismiss()
                    }
                    .labelStyle(.iconOnly)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                }

                Text("Browse by category to discover vendors for your next event.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct CategoryCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
            .hapticFeedback(.impact(weight: .light), trigger: configuration.isPressed) { old, new in
                !old && new
            }
    }
}

private struct CategoryShortcutCard: View {
    let shortcut: CategoryShortcut

    private var tone: AccentTone { shortcut.category.accentTone }

    var body: some View {
        if let imageName = shortcut.category.categoryImageName {
            CategoryImageCard(imageName: imageName, title: shortcut.category.singularTitle)
        } else {
            CategoryIconCard(shortcut: shortcut, tone: tone)
        }
    }
}

private struct CategoryImageCard: View {
    let imageName: String
    let title: String

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 140)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.black.opacity(0.45), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 64)
            }
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(14)
            }
            .clipShape(.rect(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(color: AppTheme.Palette.shadow, radius: 18, y: 12)
    }
}

private struct CategoryIconCard: View {
    let shortcut: CategoryShortcut
    let tone: AccentTone

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: shortcut.category.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(tone))
                        .frame(width: 34, height: 34)
                        .background(AppTheme.toneBackground(tone), in: .rect(cornerRadius: 10))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }

                Text(shortcut.category.singularTitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        }
    }
}
