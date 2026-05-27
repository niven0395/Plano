import SwiftUI

/// Single-screen welcome for newly signed-in hosts. Replaces the former
/// 5-slide tour — lands the user directly on a clear primary action so
/// they can start planning immediately.
struct HostOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(AppTheme.toneBackground(.blue))
                            .frame(width: 84, height: 84)

                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(AppTheme.toneColor(.blue))
                    }

                    Text("Welcome to Plano")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Plan your event. We'll help you find, message, and book the right vendors.")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button {
                        dismiss()
                        router.selectedTab = .events
                    } label: {
                        Text("Tell us about your event")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button("I'll explore first") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.accent)
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.vertical, 32)
        }
        .interactiveDismissDisabled()
    }
}
