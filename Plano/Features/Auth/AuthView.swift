import AuthenticationServices
import SwiftUI

struct AuthView: View {
    let mode: AuthSheetMode
    let store: AuthStore

    var body: some View {
        NavigationStack {
            AuthMainContent(mode: mode, store: store)
        }
    }
}

// MARK: - Auth Main Content

private struct AuthMainContent: View {
    let mode: AuthSheetMode
    let store: AuthStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(mode.subtitle)
                        .font(.body)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                AuthPrimaryOptions(store: store)

                if let message = store.loadingState.errorMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if store.loadingState.isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(AppTheme.Palette.accent)

                        Text("Signing you in")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(AppTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: store.dismissPresentedSheet)
            }
        }
    }
}

// MARK: - Primary Options (Apple hero + email secondary)

private struct AuthPrimaryOptions: View {
    let store: AuthStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.supportsAppleSignIn {
                SignInWithAppleButton(.continue) { request in
                    store.configureAppleRequest(request)
                } onCompletion: { result in
                    Task {
                        await store.handleAppleCompletion(result)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous))
                .disabled(store.loadingState.isLoading)
            }

            DividerWithLabel(label: "or")

            NavigationLink {
                EmailAuthScreen(store: store)
            } label: {
                Text("Continue with email")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Text("By continuing, you agree to Plano's Terms and Privacy Policy.")
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.subdued)
                .multilineTextAlignment(.leading)
                .padding(.top, 4)
        }
    }
}

// MARK: - Divider with label

private struct DividerWithLabel: View {
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppTheme.Palette.border)
                .frame(height: 1)

            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.subdued)

            Rectangle()
                .fill(AppTheme.Palette.border)
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Email Auth Screen

private struct EmailAuthScreen: View {
    let store: AuthStore

    var body: some View {
        ScrollView {
            EmailAuthForm(store: store)
                .padding(AppTheme.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Continue with email")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Email Auth Form

private struct EmailAuthForm: View {
    let store: AuthStore

    @State private var isSignUp = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, email, password
    }

    private var isValid: Bool {
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasEmail = emailTrimmed.contains("@") && emailTrimmed.contains(".")
        let hasPassword = password.count >= 8
        let hasName = !isSignUp || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasEmail && hasPassword && hasName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isSignUp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    TextField("Your full name", text: $name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
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
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                SecureField(isSignUp ? "At least 8 characters" : "Your password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
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

            if let message = store.loadingState.errorMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                focusedField = nil
                Task {
                    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    if isSignUp {
                        await store.signUpWithEmail(
                            email: trimmedEmail,
                            password: password,
                            displayName: name
                        )
                    } else {
                        await store.signInWithEmail(email: trimmedEmail, password: password)
                    }
                }
            } label: {
                Text(isSignUp ? "Create account" : "Sign in")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!isValid || store.loadingState.isLoading)

            if store.loadingState.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(AppTheme.Palette.accent)

                    Text(isSignUp ? "Creating your account" : "Signing in")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSignUp.toggle()
                    store.loadingState = .idle
                }
            } label: {
                Text(isSignUp
                    ? "Already have an account? Sign in"
                    : "New here? Create an account")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.accent)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .hapticFeedback(.selection, trigger: isSignUp)
            .padding(.top, 4)
        }
    }
}
