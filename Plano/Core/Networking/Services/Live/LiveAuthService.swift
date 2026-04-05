import Foundation
#if canImport(Supabase)
import Supabase

actor LiveAuthService: AuthServiceProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func restoreSession() async throws -> RestoredAuthSession? {
        do {
            let session = try await client.auth.session
            return try await restoredSession(from: session)
        } catch {
            do {
                let session = try await client.auth.refreshSession()
                return try await restoredSession(from: session)
            } catch {
                return nil
            }
        }
    }

    func signInAnonymously() async throws -> AnonymousHostSession {
        try await client.auth.signInAnonymously()
        let session = try await client.auth.session

        let existingUser = try await fetchOptionalRecord(from: "users", matching: "id", value: session.user.id) as UserRecord?
        let userRecord = UserRecord(
            id: session.user.id,
            email: session.user.email,
            displayName: existingUser?.displayName ?? "Guest host",
            preferredRole: UserRole.host.rawValue,
            anonymousDisplayName: existingUser?.anonymousDisplayName,
            contactPhone: existingUser?.contactPhone,
            contactEmail: existingUser?.contactEmail
        )

        try await upsertUser(userRecord)
        return try await fetchAnonymousSession(from: session)
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: rawNonce
            )
        )

        let displayName = makeDisplayName(email: email ?? session.user.email, givenName: givenName, familyName: familyName)
        let existingUser = try await fetchOptionalRecord(from: "users", matching: "id", value: session.user.id) as UserRecord?
        let userRecord = UserRecord(
            id: session.user.id,
            email: email ?? session.user.email,
            displayName: existingUser?.displayName ?? displayName,
            preferredRole: existingUser?.preferredRole ?? UserRole.host.rawValue,
            anonymousDisplayName: existingUser?.anonymousDisplayName,
            contactPhone: existingUser?.contactPhone,
            contactEmail: existingUser?.contactEmail
        )

        try await upsertUser(userRecord)
        return try await fetchAuthenticatedProfile(from: session)
    }

    func setHostIdentity(
        name: String,
        phone: String?,
        email: String?
    ) async throws -> AnonymousHostSession {
        let session = try await client.auth.session
        let existingUser = try await fetchOptionalRecord(from: "users", matching: "id", value: session.user.id) as UserRecord?
        let userRecord = UserRecord(
            id: session.user.id,
            email: existingUser?.email,
            displayName: name,
            preferredRole: UserRole.host.rawValue,
            anonymousDisplayName: name,
            contactPhone: phone,
            contactEmail: email
        )

        try await upsertUser(userRecord)
        return try await fetchAnonymousSession(from: session)
    }

    func upgradeAnonymousToApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        try await client.auth.linkIdentityWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: rawNonce
            )
        )

        let session = try await client.auth.session
        let existingUser = try await fetchOptionalRecord(from: "users", matching: "id", value: session.user.id) as UserRecord?
        let resolvedName = existingUser?.anonymousDisplayName
            ?? makeDisplayName(email: email ?? session.user.email, givenName: givenName, familyName: familyName)
        let userRecord = UserRecord(
            id: session.user.id,
            email: email ?? session.user.email,
            displayName: resolvedName,
            preferredRole: existingUser?.preferredRole ?? UserRole.host.rawValue,
            anonymousDisplayName: resolvedName,
            contactPhone: existingUser?.contactPhone,
            contactEmail: existingUser?.contactEmail ?? email
        )

        try await upsertUser(userRecord)
        return try await fetchAuthenticatedProfile(from: session)
    }

    func signUpWithEmail(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> EmailSignUpResult {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )

        guard let user = response.session?.user else {
            return .pendingVerification(email: email)
        }

        let resolvedName = displayName ?? makeDisplayName(email: email, givenName: nil, familyName: nil)
        let existingUser = try await fetchOptionalRecord(from: "users", matching: "id", value: user.id) as UserRecord?
        let userRecord = UserRecord(
            id: user.id,
            email: email,
            displayName: existingUser?.displayName ?? resolvedName,
            preferredRole: existingUser?.preferredRole ?? UserRole.host.rawValue,
            anonymousDisplayName: existingUser?.anonymousDisplayName ?? resolvedName,
            contactPhone: existingUser?.contactPhone,
            contactEmail: existingUser?.contactEmail ?? email
        )

        try await upsertUser(userRecord)

        let supabaseSession = try await client.auth.session
        return .authenticated(try await fetchAuthenticatedProfile(from: supabaseSession))
    }

    func resendEmailConfirmation(email: String) async throws {
        try await client.auth.resend(email: email, type: .signup)
    }

    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUserProfile {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )

        let existingUser = try await fetchOptionalRecord(from: "users", matching: "id", value: session.user.id) as UserRecord?
        if existingUser == nil {
            let displayName = makeDisplayName(email: email, givenName: nil, familyName: nil)
            let userRecord = UserRecord(
                id: session.user.id,
                email: email,
                displayName: displayName,
                preferredRole: UserRole.host.rawValue,
                anonymousDisplayName: nil,
                contactPhone: nil,
                contactEmail: email
            )
            try await upsertUser(userRecord)
        }

        return try await fetchAuthenticatedProfile(from: session)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws -> DeletionResult {
        let result: DeletionResult = try await client.rpc("delete_account_with_cascades")
            .execute()
            .value
        try await client.auth.signOut()
        return result
    }

    private func fetchAnonymousSession(from session: Session) async throws -> AnonymousHostSession {
        let userRecord = try await fetchOptionalRecord(from: "users", matching: "id", value: session.user.id) as UserRecord?

        return AnonymousHostSession(
            userID: session.user.id,
            displayName: userRecord?.anonymousDisplayName,
            contactPhone: userRecord?.contactPhone,
            contactEmail: userRecord?.contactEmail,
            isLinkedToApple: !(session.user.identities?.isEmpty ?? true) && !session.user.isAnonymous,
            emailAddress: userRecord?.email ?? session.user.email
        )
    }

    private func restoredSession(from session: Session) async throws -> RestoredAuthSession {
        if session.user.isAnonymous {
            return .anonymous(try await fetchAnonymousSession(from: session))
        }

        return .authenticated(try await fetchAuthenticatedProfile(from: session))
    }

    private func fetchAuthenticatedProfile(from session: Session) async throws -> AuthenticatedUserProfile {
        let userRecord = try await fetchOptionalRecord(from: "users", matching: "id", value: session.user.id) as UserRecord?
        let vendorProfile = try await fetchOptionalRecord(from: "vendor_profiles", matching: "user_id", value: session.user.id) as VendorProfileRecord?

        let personalName = userRecord?.displayName ?? makeDisplayName(
            email: session.user.email,
            givenName: nil,
            familyName: nil
        )

        let vendorDisplayName: String? = if let vendorProfile, vendorProfile.onboardedAt != nil {
            vendorProfile.businessName
        } else {
            nil
        }

        return AuthenticatedUserProfile(
            userID: session.user.id,
            emailAddress: userRecord?.email ?? session.user.email,
            displayName: personalName,
            vendorDisplayName: vendorDisplayName
        )
    }

    private func upsertUser(_ userRecord: UserRecord) async throws {
        try await client.from("users")
            .upsert(userRecord, onConflict: "id")
            .execute()
    }

    private func fetchOptionalRecord<Record: Decodable>(
        from table: String,
        matching column: String,
        value: UUID
    ) async throws -> Record? {
        do {
            return try await client.from(table)
                .select()
                .eq(column, value: value)
                .single()
                .execute()
                .value
        } catch {
            return nil
        }
    }

    private func makeDisplayName(
        email: String?,
        givenName: String?,
        familyName: String?
    ) -> String {
        let components = [givenName, familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !components.isEmpty {
            return components.joined(separator: " ")
        }

        if let email,
           let localPart = email.split(separator: "@").first,
           !localPart.isEmpty {
            return localPart.replacingOccurrences(of: ".", with: " ").capitalized
        }

        return "Plano User"
    }
}
#else
actor LiveAuthService: AuthServiceProtocol {
    init(client: Any? = nil) {}

    func restoreSession() async throws -> RestoredAuthSession? {
        nil
    }

    func signInAnonymously() async throws -> AnonymousHostSession {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func setHostIdentity(
        name: String,
        phone: String?,
        email: String?
    ) async throws -> AnonymousHostSession {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func upgradeAnonymousToApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func signUpWithEmail(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> EmailSignUpResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func resendEmailConfirmation(email: String) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUserProfile {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func signOut() async throws {}

    func deleteAccount() async throws -> DeletionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }
}
#endif
