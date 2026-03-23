import SwiftUI

struct EmailVerificationView: View {
    let email: String
    let store: AuthStore

    @State private var code = ""
    @State private var resendCooldown = 0
    @FocusState private var isCodeFieldFocused: Bool

    private var isValid: Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).count == 8
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppSurface(style: .highlighted) {
                    VStack(alignment: .leading, spacing: 18) {
                        StatusBadge(title: "Verify your email", tone: .sage)

                        SectionHeader(
                            title: "Check your inbox",
                            subtitle: "We sent an 8-digit code to \(email). Enter it below to verify your account."
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Verification code")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    TextField("8-digit code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isCodeFieldFocused)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            AppTheme.Palette.inputFill,
                            in: .rect(cornerRadius: AppTheme.compactCornerRadius)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.compactCornerRadius)
                                .stroke(AppTheme.Palette.border, lineWidth: 1)
                        }
                }

                Button {
                    isCodeFieldFocused = false
                    Task {
                        await store.verifyOTP(code: code.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } label: {
                    Text("Verify")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!isValid || store.verificationLoadingState.isLoading)

                ResendCodeButton(
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

                        Text("Verifying")
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
                Button("Back") {
                    store.cancelVerification()
                }
            }
        }
        .onAppear {
            isCodeFieldFocused = true
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

// MARK: - Resend Code Button

private struct ResendCodeButton: View {
    let cooldownRemaining: Int
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            if cooldownRemaining > 0 {
                Text("Resend code in \(cooldownRemaining)s")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.subdued)
            } else {
                Text("Resend code")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.accent)
            }
        }
        .buttonStyle(.plain)
        .disabled(cooldownRemaining > 0 || isLoading)
    }
}
