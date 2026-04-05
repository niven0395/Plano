import SwiftUI

struct EmailVerificationView: View {
    let email: String
    let store: AuthStore

    @State private var resendCooldown = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppSurface(style: .highlighted) {
                    VStack(alignment: .leading, spacing: 18) {
                        StatusBadge(title: "Check your email", tone: .sage)

                        SectionHeader(
                            title: "Verification sent",
                            subtitle: "We sent a verification link to \(email). Open the email and tap the link to verify your account, then come back here to sign in."
                        )
                    }
                }

                if let message = store.verificationLoadingState.errorMessage {
                    AppSurface {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

                Button("Go to Sign In") {
                    store.completeSignUpAndDismiss()
                }
                .buttonStyle(PrimaryActionButtonStyle())

                ResendEmailButton(
                    cooldownRemaining: resendCooldown,
                    isLoading: store.verificationLoadingState.isLoading
                ) {
                    Task {
                        await store.resendVerification()
                        startResendCooldown()
                    }
                }

                if store.verificationLoadingState.isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(AppTheme.Palette.accent)

                        Text("Sending")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Verify email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    store.dismissPresentedSheet()
                }
            }
        }
        .onAppear {
            startResendCooldown()
        }
    }

    private func startResendCooldown() {
        resendCooldown = 60
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendCooldown -= 1
            }
        }
    }
}

// MARK: - Resend Email Button

private struct ResendEmailButton: View {
    let cooldownRemaining: Int
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            if cooldownRemaining > 0 {
                Text("Resend email in \(cooldownRemaining)s")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.subdued)
            } else {
                Text("Resend verification email")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.accent)
            }
        }
        .buttonStyle(.plain)
        .disabled(cooldownRemaining > 0 || isLoading)
    }
}
