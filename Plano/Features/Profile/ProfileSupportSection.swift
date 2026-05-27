import SwiftUI

struct ProfileSupportSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            AppSurface {
                VStack(spacing: 0) {
                    linkRow(
                        title: "Help & Support",
                        subtitle: "Get answers from the team",
                        symbol: "questionmark.circle.fill",
                        tone: .blue,
                        url: SupportLinks.help,
                        isExternal: true
                    )
                    Divider().padding(.horizontal, -22)
                    linkRow(
                        title: "Privacy Policy",
                        subtitle: "How we handle your data",
                        symbol: "hand.raised.fill",
                        tone: .sage,
                        url: SupportLinks.privacy,
                        isExternal: true
                    )
                    Divider().padding(.horizontal, -22)
                    linkRow(
                        title: "Terms of Service",
                        subtitle: "The rules of the road",
                        symbol: "doc.text.fill",
                        tone: .sand,
                        url: SupportLinks.terms,
                        isExternal: true
                    )
                }
            }

            versionFooter
        }
    }

    private func linkRow(
        title: String,
        subtitle: String,
        symbol: String,
        tone: AccentTone,
        url: URL,
        isExternal: Bool
    ) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.toneBackground(tone))
                    Image(systemName: symbol)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(tone))
                }
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Spacer(minLength: 8)

                Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
            }
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(isExternal ? "Opens in browser" : "")
    }

    private var versionFooter: some View {
        Text(versionString)
            .font(.caption2)
            .foregroundStyle(AppTheme.Palette.subdued)
            .frame(maxWidth: .infinity)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Plano v\(version) (\(build))"
    }

    private enum SupportLinks {
        static let terms = URL(string: "https://plano.app/terms")!
        static let privacy = URL(string: "https://plano.app/privacy")!
        static let help = URL(string: "mailto:support@plano.app")!
    }
}
