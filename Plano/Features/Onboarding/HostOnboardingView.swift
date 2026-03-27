import SwiftUI

struct HostOnboardingView: View {
    @Environment(HostPlanningStore.self) private var planner
    @Environment(AppRouter.self) private var router
    @State private var pageIndex = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Start from the event, not the vendor list",
            body: "Every search, saved vendor, and booking stays connected to your event — so nothing gets lost or mixed up.",
            symbolName: "calendar.badge.plus",
            tone: .blue
        ),
        OnboardingPage(
            title: "Shortlist with confidence",
            body: "Filter by category, price, availability, and how quickly vendors respond — so you see the best matches first.",
            symbolName: "heart.circle.fill",
            tone: .coral
        ),
        OnboardingPage(
            title: "Keep state visible",
            body: "Pick an event once, and your searches, messages, and bookings all stay in sync automatically.",
            symbolName: "square.stack.3d.up.fill",
            tone: .sage
        ),
    ]

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(spacing: 24) {
                TabView(selection: $pageIndex) {
                    ForEach(pages.enumerated(), id: \.element.id) { index, page in
                        AppSurface(style: .highlighted) {
                            VStack(alignment: .leading, spacing: 18) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 26)
                                        .fill(AppTheme.toneBackground(page.tone))
                                        .frame(width: 74, height: 74)

                                    Image(systemName: page.symbolName)
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(AppTheme.toneColor(page.tone))
                                }

                                Text(page.title)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                Text(page.body)
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        }
                        .tag(index)
                        .padding(.horizontal, AppTheme.screenPadding)
                        .padding(.top, 60)
                        .padding(.bottom, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == pageIndex ? AppTheme.Palette.accent : AppTheme.Palette.border)
                            .frame(width: index == pageIndex ? 28 : 10, height: 10)
                    }
                }

                VStack(spacing: 12) {
                    Button(pageIndex == pages.indices.last ? "Start planning" : "Continue") {
                        if pageIndex == pages.indices.last {
                            planner.completeOnboarding()
                            router.selectedTab = .home
                        } else {
                            pageIndex += 1
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Text("Set up your event, browse vendors, and start building your shortlist.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct OnboardingPage: Identifiable {
    let id: String
    let title: String
    let body: String
    let symbolName: String
    let tone: AccentTone

    init(title: String, body: String, symbolName: String, tone: AccentTone) {
        self.id = title
        self.title = title
        self.body = body
        self.symbolName = symbolName
        self.tone = tone
    }
}
