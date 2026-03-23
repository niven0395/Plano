import AuthenticationServices
import SwiftUI

struct AuthView: View {
    let mode: AuthSheetMode
    let store: AuthStore

    var body: some View {
        NavigationStack {
            if let verificationEmail = store.pendingVerificationEmail {
                EmailVerificationView(email: verificationEmail, store: store)
            } else {
                AuthMainContent(mode: mode, store: store)
            }
        }
    }
}

// MARK: - Auth Main Content

private struct AuthMainContent: View {
    let mode: AuthSheetMode
    let store: AuthStore

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppSurface(style: .highlighted) {
                    VStack(alignment: .leading, spacing: 18) {
                        StatusBadge(
                            title: environment.services.isConfigured ? "Live backend" : "Backend unavailable",
                            tone: environment.services.isConfigured ? .sage : .gold
                        )

                        SectionHeader(
                            title: mode.title,
                            subtitle: mode.subtitle
                        )

                        Text(environment.transportSummary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

                if let message = store.loadingState.errorMessage {
                    AppSurface {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

                switch mode {
                case .emailAuth:
                    EmailAuthForm(store: store)

                case .vendorSignIn, .hostUpgrade:
                    if store.supportsAppleSignIn {
                        SignInWithAppleButton(.signIn) { request in
                            store.configureAppleRequest(request)
                        } onCompletion: { result in
                            Task {
                                await store.handleAppleCompletion(result)
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous))
                        .disabled(store.loadingState.isLoading)
                    }
                }

                if store.loadingState.isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(AppTheme.Palette.accent)

                        Text("Preparing your session")
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
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: store.dismissPresentedSheet)
            }
        }
    }
}

// MARK: - Email Auth Form

private struct EmailAuthForm: View {
    let store: AuthStore

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName, lastName, email, password
    }

    private var isValid: Bool {
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasEmail = emailTrimmed.contains("@") && emailTrimmed.contains(".")
        let hasPassword = password.count >= 6
        if isSignUp {
            let hasFirstName = !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasLastName = !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasEmail && hasPassword && hasFirstName && hasLastName
        }
        return hasEmail && hasPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isSignUp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("First name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .firstName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .lastName }
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
                    Text("Last name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .lastName)
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

                SecureField("At least 6 characters", text: $password)
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

            Button {
                focusedField = nil
                Task {
                    if isSignUp {
                        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let fullName = [trimmedFirst, trimmedLast]
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                        await store.signUpWithEmail(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password,
                            displayName: fullName.isEmpty ? nil : fullName
                        )
                    } else {
                        await store.signInWithEmail(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password
                        )
                    }
                }
            } label: {
                Text(isSignUp ? "Create account" : "Sign in")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!isValid || store.loadingState.isLoading)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSignUp.toggle()
                    store.loadingState = .idle
                }
            } label: {
                Text(isSignUp
                    ? "Already have an account? Sign in"
                    : "Don't have an account? Create one")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.accent)
            }
            .buttonStyle(.plain)
            .hapticFeedback(.selection, trigger: isSignUp)
        }
    }
}
