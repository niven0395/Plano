import AuthenticationServices
import CryptoKit
import Foundation
import Observation

enum AuthSheetMode: String, Identifiable {
    case vendorSignIn
    case hostUpgrade
    case emailAuth
    case createAccount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vendorSignIn:
            "List your business"
        case .hostUpgrade:
            "Sign in with Apple"
        case .emailAuth:
            "Sign in"
        case .createAccount:
            "Create an account"
        }
    }

    var subtitle: String {
        switch self {
        case .vendorSignIn:
            "Sign in with Apple to create your vendor profile and start receiving leads."
        case .hostUpgrade:
            "Link this device session to Apple so your saved vendors and messages carry across devices."
        case .emailAuth:
            "Sign in or create an account with your email address."
        case .createAccount:
            "Keep your saved vendors, messages, and bookings across devices."
        }
    }
}

@MainActor
@Observable
final class AuthStore {
    private let authService: any AuthServiceProtocol
    private let sessionStore: SessionStore
    @ObservationIgnored private var didRestoreSession = false
    @ObservationIgnored private var currentNonce: String?
    @ObservationIgnored private var pendingVendorOnboarding = false

    let supportsAppleSignIn: Bool

    var loadingState: LoadingState = .idle
    var presentedSheet: AuthSheetMode?
    private(set) var pendingVerificationEmail: String?
    var verificationLoadingState: LoadingState = .idle
    var showEmailSignInAfterVerification = false

    init(
        authService: any AuthServiceProtocol,
        sessionStore: SessionStore,
        supportsAppleSignIn: Bool
    ) {
        self.authService = authService
        self.sessionStore = sessionStore
        self.supportsAppleSignIn = supportsAppleSignIn
    }

    func restoreSessionIfNeeded() async {
        guard !didRestoreSession else { return }
        didRestoreSession = true
        await initializeSession()
    }

    func initializeSession() async {
        sessionStore.beginInitialization()
        loadingState = .loading

        do {
            if let restored = try await authService.restoreSession() {
                apply(restored)
            } else {
                let anonymousSession = try await authService.signInAnonymously()
                sessionStore.applyAnonymousSession(anonymousSession)
            }

            loadingState = .loaded
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    func startVendorSetup() {
        if sessionStore.isAuthenticated {
            sessionStore.beginVendorOnboarding()
        } else {
            pendingVendorOnboarding = true
            presentedSheet = .vendorSignIn
        }
    }

    func presentHostUpgrade() {
        presentedSheet = .hostUpgrade
    }

    func dismissPresentedSheet() {
        presentedSheet = nil
        pendingVendorOnboarding = false
        pendingVerificationEmail = nil
        verificationLoadingState = .idle
        showEmailSignInAfterVerification = false
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce

        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                loadingState = .failed("Apple Sign In did not return a compatible credential.")
                return
            }

            guard let currentNonce else {
                loadingState = .failed("Apple Sign In could not validate the request nonce.")
                return
            }

            guard let identityToken = credential.identityToken,
                  let idToken = String(data: identityToken, encoding: .utf8),
                  !idToken.isEmpty else {
                loadingState = .failed("Apple Sign In did not return an identity token.")
                return
            }

            await handleSignIn(
                mode: presentedSheet,
                idToken: idToken,
                rawNonce: currentNonce,
                email: credential.email,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName
            )

        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                loadingState = .idle
                pendingVendorOnboarding = false
                return
            }

            loadingState = .failed(error.localizedDescription)
        }
    }

    func setHostIdentity(
        firstName: String,
        lastName: String,
        phone: String,
        email: String
    ) async throws {
        let combinedName = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let updatedSession = try await authService.setHostIdentity(
            name: combinedName,
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        sessionStore.applyAnonymousSession(updatedSession)
    }

    func presentCreateAccount() {
        presentedSheet = .createAccount
    }

    func presentEmailAuth() {
        presentedSheet = .emailAuth
    }

    func signInWithEmail(email: String, password: String) async {
        loadingState = .loading

        do {
            let profile = try await authService.signInWithEmail(
                email: email,
                password: password
            )

            sessionStore.applyAuthenticatedSession(profile, preferredRole: .host)
            presentedSheet = nil
            pendingVendorOnboarding = false
            loadingState = .loaded
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    func signUpWithEmail(email: String, password: String, displayName: String?) async {
        loadingState = .loading

        do {
            let result = try await authService.signUpWithEmail(
                email: email,
                password: password,
                displayName: displayName
            )

            switch result {
            case .authenticated(let profile):
                sessionStore.applyAuthenticatedSession(profile, preferredRole: .host)
                presentedSheet = nil
                pendingVendorOnboarding = false
                loadingState = .loaded

            case .pendingVerification(let email):
                pendingVerificationEmail = email
                loadingState = .loaded
            }
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    func completeSignUpAndDismiss() {
        pendingVerificationEmail = nil
        verificationLoadingState = .idle
        loadingState = .idle
        showEmailSignInAfterVerification = true
    }

    func resendVerification() async {
        guard let email = pendingVerificationEmail else { return }
        verificationLoadingState = .loading

        do {
            try await authService.resendEmailConfirmation(email: email)
            verificationLoadingState = .loaded
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            verificationLoadingState = .failed(error.localizedDescription)
        }
    }

    func cancelVerification() {
        pendingVerificationEmail = nil
        verificationLoadingState = .idle
    }

    func signOut() async {
        loadingState = .loading

        do {
            try await authService.signOut()
        } catch is CancellationError {
            return
        } catch {
            loadingState = .failed(error.localizedDescription)
            return
        }

        presentedSheet = nil
        pendingVendorOnboarding = false

        // Establish anonymous session FIRST so the auth token is valid
        // when handleIdentityStateChange triggers data loading.
        do {
            let anonymousSession = try await authService.signInAnonymously()
            sessionStore.applyAnonymousSession(anonymousSession)
        } catch {
            // Anonymous sign-in failed — fall back to tokenless anonymous state.
            sessionStore.resetToAnonymous()
        }

        loadingState = .loaded
    }

    func deleteAccount() async -> DeletionResult? {
        loadingState = .loading

        do {
            let result = try await authService.deleteAccount()
            let anonymousSession = try await authService.signInAnonymously()
            sessionStore.applyAnonymousSession(anonymousSession)
            presentedSheet = nil
            pendingVendorOnboarding = false
            loadingState = .loaded
            return result
        } catch is CancellationError {
            return nil
        } catch {
            loadingState = .failed(error.localizedDescription)
            return nil
        }
    }

    private func handleSignIn(
        mode: AuthSheetMode?,
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async {
        loadingState = .loading

        do {
            let profile: AuthenticatedUserProfile

            if sessionStore.isAnonymous {
                do {
                    profile = try await authService.upgradeAnonymousToApple(
                        idToken: idToken,
                        rawNonce: rawNonce,
                        email: email,
                        givenName: givenName,
                        familyName: familyName
                    )
                } catch {
                    // Link fails when the Apple identity is already bound to a
                    // previous user (e.g. after sign-out created a new anonymous
                    // session). Fall back to a regular sign-in which will
                    // authenticate as the existing user instead.
                    profile = try await authService.signInWithApple(
                        idToken: idToken,
                        rawNonce: rawNonce,
                        email: email,
                        givenName: givenName,
                        familyName: familyName
                    )
                }
            } else {
                profile = try await authService.signInWithApple(
                    idToken: idToken,
                    rawNonce: rawNonce,
                    email: email,
                    givenName: givenName,
                    familyName: familyName
                )
            }

            let preferredRole: UserRole? = switch mode {
            case .vendorSignIn:
                profile.isVendorOnboarded ? .vendor : .host
            case .hostUpgrade, .emailAuth, .createAccount, nil:
                .host
            }

            sessionStore.applyAuthenticatedSession(profile, preferredRole: preferredRole)

            if pendingVendorOnboarding, !profile.isVendorOnboarded {
                sessionStore.beginVendorOnboarding()
            }

            presentedSheet = nil
            pendingVendorOnboarding = false
            loadingState = .loaded
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    private func apply(_ restoredSession: RestoredAuthSession) {
        switch restoredSession {
        case .anonymous(let session):
            sessionStore.applyAnonymousSession(session)
        case .authenticated(let profile):
            sessionStore.applyAuthenticatedSession(profile)
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                UInt8.random(in: 0...255)
            }

            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
