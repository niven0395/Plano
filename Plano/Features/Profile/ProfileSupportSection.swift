import SwiftUI

struct ProfileSupportSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            AppSurface {
                VStack(spacing: 0) {
                    linkRow("Terms of Service", url: SupportLinks.terms)
                    Divider().padding(.horizontal, -22)
                    linkRow("Privacy Policy", url: SupportLinks.privacy)
                    Divider().padding(.horizontal, -22)
                    linkRow("Help & Support", url: SupportLinks.help)
                }
            }

            versionFooter
        }
    }

    private func linkRow(_ title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
