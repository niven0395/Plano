import Foundation
import Testing
@testable import Plano

struct AuthStoreTests {
    @Test
    @MainActor
    func initialStateIsIdle() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            #expect(authStore.loadingState == .idle)
            #expect(authStore.presentedSheet == nil)
        }
    }

    @Test
    @MainActor
    func errorStateIsSetWhenSignInFails() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: FailingAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()

            #expect(authStore.loadingState == .failed("Sign-in failed."))
        }
    }

    @Test
    @MainActor
    func sessionRestorationWorks() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()

            #expect(authStore.loadingState == .loaded)
            #expect(sessionStore.identityState == .anonymous)
            #expect(sessionStore.canBrowse)
        }
    }

    @Test
    @MainActor
    func authenticatedSessionRestorationSetsCorrectState() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(restoredSession: .authenticated(FixtureData.vendorSession)),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()

            #expect(authStore.loadingState == .loaded)
            #expect(sessionStore.identityState == .authenticated)
            #expect(sessionStore.isAuthenticated)
        }
    }

    @Test
    @MainActor
    func restoreSessionOnlyRunsOnce() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()
            #expect(authStore.loadingState == .loaded)

            await authStore.restoreSessionIfNeeded()
            #expect(authStore.loadingState == .loaded)
        }
    }

    @Test
    @MainActor
    func signOutResetsToAnonymousSession() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(restoredSession: .authenticated(FixtureData.vendorSession)),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()
            #expect(sessionStore.isAuthenticated)

            await authStore.signOut()

            #expect(sessionStore.identityState == .anonymous)
            #expect(sessionStore.currentRole == .host)
            #expect(authStore.loadingState == .loaded)
        }
    }

    @Test
    @MainActor
    func setHostIdentityUnlocksMessaging() async throws {
        try await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()
            #expect(sessionStore.canMessage == false)

            try await authStore.setHostIdentity(
                firstName: "Maya",
                lastName: "Chen",
                phone: "(416) 555-0100",
                email: "maya@example.com"
            )

            #expect(sessionStore.canMessage)
            #expect(sessionStore.identityState == .identified(name: "Maya Chen"))
        }
    }

    @Test
    @MainActor
    func startVendorSetupPresentsSheetWhenNotAuthenticated() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()

            authStore.startVendorSetup()

            #expect(authStore.presentedSheet == .vendorSignIn)
        }
    }

    @Test
    @MainActor
    func startVendorSetupBeginsOnboardingWhenAuthenticated() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAuthenticatedSession(FixtureData.vendorSession, preferredRole: .host)
            let authStore = AuthStore(
                authService: TestAuthService(restoredSession: .authenticated(FixtureData.vendorSession)),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            authStore.startVendorSetup()

            #expect(authStore.presentedSheet == nil)
            #expect(sessionStore.requiresVendorOnboarding)
        }
    }

    @Test
    @MainActor
    func dismissPresentedSheetClearsState() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.restoreSessionIfNeeded()
            authStore.startVendorSetup()
            #expect(authStore.presentedSheet == .vendorSignIn)

            authStore.dismissPresentedSheet()

            #expect(authStore.presentedSheet == nil)
        }
    }

    @Test
    @MainActor
    func signOutAfterFailureResetsState() async {
        await withIsolatedDefaults { defaults in
            let sessionStore = SessionStore(defaults: defaults)
            sessionStore.applyAuthenticatedSession(FixtureData.vendorSession, preferredRole: .vendor)
            let authStore = AuthStore(
                authService: TestAuthService(),
                sessionStore: sessionStore,
                supportsAppleSignIn: false
            )

            await authStore.signOut()

            #expect(sessionStore.identityState == .anonymous)
            #expect(sessionStore.currentRole == .host)
            #expect(authStore.presentedSheet == nil)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func withIsolatedDefaults(_ body: (UserDefaults) async throws -> Void) async rethrows {
        let suiteName = "PlanoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try await body(defaults)
    }
}

/// An auth service that always throws, used to test error handling paths.
actor FailingAuthService: AuthServiceProtocol {
    func restoreSession() async throws -> RestoredAuthSession? {
        throw TestAuthError.signInFailed
    }

    func signInAnonymously() async throws -> AnonymousHostSession {
        throw TestAuthError.signInFailed
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        throw TestAuthError.signInFailed
    }

    func setHostIdentity(
        name: String,
        phone: String?,
        email: String?
    ) async throws -> AnonymousHostSession {
        throw TestAuthError.signInFailed
    }

    func upgradeAnonymousToApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        throw TestAuthError.signInFailed
    }

    func signUpWithEmail(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> EmailSignUpResult {
        throw TestAuthError.signInFailed
    }

    func resendEmailConfirmation(email: String) async throws {
        throw TestAuthError.signInFailed
    }

    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUserProfile {
        throw TestAuthError.signInFailed
    }

    func signOut() async throws {
        throw TestAuthError.signInFailed
    }

    func deleteAccount() async throws -> DeletionResult {
        throw TestAuthError.signInFailed
    }
}

private enum TestAuthError: LocalizedError {
    case signInFailed

    var errorDescription: String? {
        switch self {
        case .signInFailed:
            "Sign-in failed."
        }
    }
}
