import Foundation

protocol AuthServiceProtocol {
    func restoreSession() async throws -> RestoredAuthSession?
    func signInAnonymously() async throws -> AnonymousHostSession
    func signInWithApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile
    func setHostIdentity(
        name: String,
        phone: String?,
        email: String?
    ) async throws -> AnonymousHostSession
    func upgradeAnonymousToApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile
    func signUpWithEmail(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> EmailSignUpResult
    func verifyEmailOTP(email: String, token: String) async throws -> AuthenticatedUserProfile
    func resendEmailConfirmation(email: String) async throws
    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUserProfile
    func signOut() async throws
    func deleteAccount() async throws -> DeletionResult
}
