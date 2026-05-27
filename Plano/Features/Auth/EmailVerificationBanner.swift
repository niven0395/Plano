import SwiftUI

/// Slim banner shown at the top of the root shell when a user has an email
/// sign-up pending verification. Tapping it opens a compact sheet with
/// resend + return-to-sign-in actions, so verification never blocks browsing.
struct EmailVerificationBanner: View {
    let email: String
    let store: AuthStore

    @State private var sheetPresented = false

    var body: some View {
        Button {
            sheetPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Palette.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Verify your email to finish signing in")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(email)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppTheme.Palette.inputFill,
                in: .rect(cornerRadius: AppTheme.compactCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.compactCornerRadius)
                    .stroke(AppTheme.Palette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Verify email. Tap to resend or sign in.")
        .sheet(isPresented: $sheetPresented) {
            EmailVerificationActionsSheet(email: email, store: store)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Actions Sheet

private struct EmailVerificationActionsSheet: View {
    let email: String
    let store: AuthStore

    @Environment(\.dismiss) private var dismiss
    @State private var resendCooldown = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Check your email")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("We sent a verification link to \(email). Open it to activate your account, then come back and sign in.")
                            .font(.body)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    if let message = store.verificationLoadingState.errorMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                            store.dismissVerificationBanner()
                            store.presentSignIn()
                        } label: {
                            Text("I've verified — sign me in")
                                .frame(maxWidth: .infinity)
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

                        Button("Dismiss", role: .cancel) {
                            store.dismissVerificationBanner()
                            dismiss()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.subdued)
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
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AppBackdrop())
            .onAppear { startResendCooldown() }
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

// MARK: - Resend button

private struct ResendEmailButton: View {
    let cooldownRemaining: Int
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if cooldownRemaining > 0 {
                    Text("Resend email in \(cooldownRemaining)s")
                        .foregroundStyle(AppTheme.Palette.subdued)
                } else {
                    Text("Resend verification email")
                        .foregroundStyle(AppTheme.Palette.accent)
                }
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(cooldownRemaining > 0 || isLoading)
    }
}
