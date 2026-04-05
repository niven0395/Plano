import SwiftUI

struct HostOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Find the right vendors",
            body: "Browse by category, filter by price and availability, and shortlist the ones that stand out.",
            symbolName: "magnifyingglass",
            tone: .blue
        ),
        OnboardingPage(
            title: "Message them directly",
            body: "Ask questions, share details, and get quotes — all in one conversation thread per vendor.",
            symbolName: "bubble.left.and.bubble.right.fill",
            tone: .coral
        ),
        OnboardingPage(
            title: "Book with confidence",
            body: "Request a booking, review the quote, and confirm — with every step tracked in one place.",
            symbolName: "checkmark.seal.fill",
            tone: .sage
        ),
        OnboardingPage(
            title: "Pay securely",
            body: "Approve deposits and payments through the app. Receipts land in your conversation automatically.",
            symbolName: "creditcard.fill",
            tone: .gold
        ),
        OnboardingPage(
            title: "Stay organized",
            body: "Save vendors to your shortlist, request bookings, and manage everything from your planning hub.",
            symbolName: "list.clipboard.fill",
            tone: .blue
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
                    Button(pageIndex == pages.indices.last ? "Get started" : "Continue") {
                        if pageIndex == pages.indices.last {
                            dismiss()
                        } else {
                            pageIndex += 1
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Text("Your party planning starts here.")
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
