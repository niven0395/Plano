import SwiftUI

struct ProfileAuthActions: View {
    let isAnonymous: Bool
    let isVendorAuthenticated: Bool
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        if isAnonymous {
            anonymousActions
        } else if !isVendorAuthenticated {
            vendorPrompt
        }
    }

    private var anonymousActions: some View {
        Button("Sign in or create an account") {
            authStore.presentSignIn()
        }
        .buttonStyle(PrimaryActionButtonStyle())
    }

    private var vendorPrompt: some View {
        Button {
            authStore.startVendorSetup()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.toneBackground(.sage))
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.sage))
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Earn on Plano")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("List your business and start receiving bookings.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.toneColor(.sage))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.toneBackground(.sage).opacity(0.55), in: .rect(cornerRadius: AppTheme.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(AppTheme.toneColor(.sage).opacity(0.35), lineWidth: 1)
            }
            .shadow(color: AppTheme.Palette.shadow, radius: 14, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Earn on Plano — list your business")
    }
}
