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

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(
                title: "Browse by category",
                subtitle: "Curated vendors across every slice of your event."
            )

            if let hero = categories.first {
                Button {
                    onSelect(hero.category)
                } label: {
                    CategoryHeroCard(shortcut: hero)
                }
                .buttonStyle(CategoryCardButtonStyle())
                .staggeredAppear(index: 0)
            }

            if categories.count > 1 {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(Array(categories.dropFirst().enumerated()), id: \.element.id) { index, shortcut in
                        Button {
                            onSelect(shortcut.category)
                        } label: {
                            CategoryShortcutCard(shortcut: shortcut)
                        }
                        .buttonStyle(CategoryCardButtonStyle())
                        .staggeredAppear(index: index + 1)
                    }
                }
            }
        }
    }
}

private struct WelcomeHeroCard: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Welcome")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.accent)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text("Find your perfect vendors")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Browse by category or search directly to discover vendors for your next event.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(26)
            .padding(.trailing, 40)
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.Palette.elevatedSurface,
                        AppTheme.toneBackground(.sand).opacity(0.45),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: AppTheme.cardCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(AppTheme.Palette.border, lineWidth: 1)
            }
            .shadow(color: AppTheme.Palette.shadow, radius: 18, y: 12)

            Button("Dismiss welcome", systemImage: "xmark") {
                onDismiss()
            }
            .labelStyle(.iconOnly)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Palette.textSecondary)
            .frame(width: 32, height: 32)
            .background(AppTheme.Palette.chipFill, in: Circle())
            .padding(14)
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
    var height: CGFloat = 150

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .overlay(alignment: .bottom) {
                CategoryGlassCaption(title: title, isCompact: true)
            }
            .clipShape(.rect(cornerRadius: AppTheme.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: AppTheme.Palette.shadow, radius: 14, y: 10)
    }
}

private struct CategoryIconCard: View {
    let shortcut: CategoryShortcut
    let tone: AccentTone
    var height: CGFloat = 150

    var body: some View {
        EditorialArtworkPanel(
            tone: tone,
            symbolName: shortcut.category.symbolName,
            height: height
        )
        .overlay(alignment: .bottom) {
            CategoryGlassCaption(title: shortcut.category.singularTitle, isCompact: true)
        }
        .shadow(color: AppTheme.Palette.shadow, radius: 14, y: 10)
    }
}

// MARK: - Hero Category Card (first tile — full width)

private struct CategoryHeroCard: View {
    let shortcut: CategoryShortcut

    private var tone: AccentTone { shortcut.category.accentTone }

    private let height: CGFloat = 220

    var body: some View {
        Group {
            if let imageName = shortcut.category.categoryImageName {
                heroImage(imageName)
            } else {
                heroEditorial
            }
        }
        .clipShape(.rect(cornerRadius: AppTheme.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: AppTheme.Palette.shadow, radius: 18, y: 14)
    }

    private func heroImage(_ imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                heroCaption
            }
    }

    private var heroEditorial: some View {
        EditorialArtworkPanel(
            tone: tone,
            symbolName: shortcut.category.symbolName,
            height: height
        )
        .overlay(alignment: .bottomLeading) {
            heroCaption
        }
    }

    private var heroCaption: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Start here")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(alignment: .lastTextBaseline) {
                Text(shortcut.category.singularTitle)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .tracking(-0.4)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Glass caption strip for standard cards

private struct CategoryGlassCaption: View {
    let title: String
    let isCompact: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isCompact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
    }
}
