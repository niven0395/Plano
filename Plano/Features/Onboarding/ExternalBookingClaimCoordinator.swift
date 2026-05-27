import Foundation
import OSLog
import Observation

/// Coordinates "claim" of an external booking request — the conversation
/// that was created by a non-authenticated user via the App Clip or web
/// booking form. When the user signs in with the same email the invite was
/// issued to, their account is linked to the conversation and future chat
/// happens natively in-app.
///
/// Call-sites:
/// - `PlanoRootView.onContinueUserActivity` when a `/claim?token=...` deep
///   link arrives. If the user is authenticated, claims immediately. Otherwise
///   the token is stashed and the auth sheet is presented.
/// - `AuthStore` after a successful sign-in, to run any stashed token + sweep
///   invites whose email matches the newly signed-in user.
@MainActor
@Observable
final class ExternalBookingClaimCoordinator {
    private let claimService: any ExternalBookingClaimServiceProtocol
    private let sessionStore: SessionStore
    private let router: AppRouter

    @ObservationIgnored private var pendingToken: String?
    private(set) var lastClaimedConversationID: UUID?
    private(set) var isClaiming = false

    init(
        claimService: any ExternalBookingClaimServiceProtocol,
        sessionStore: SessionStore,
        router: AppRouter
    ) {
        self.claimService = claimService
        self.sessionStore = sessionStore
        self.router = router
    }

    /// Handle an inbound `/claim` universal link. If already authenticated,
    /// the claim runs now. Otherwise the token is stashed for after sign-in.
    func handle(token: String?) async {
        guard let token, !token.isEmpty else {
            if sessionStore.isAuthenticated {
                await runClaim(token: nil)
            }
            return
        }

        if sessionStore.isAuthenticated {
            await runClaim(token: token)
        } else {
            pendingToken = token
        }
    }

    /// Run after sign-in completes. Uses any stashed token and then sweeps
    /// further invites matching the user's email.
    func runPostSignInSweep() async {
        let token = pendingToken
        pendingToken = nil
        await runClaim(token: token)
    }

    private func runClaim(token: String?) async {
        guard !isClaiming else { return }
        isClaiming = true
        defer { isClaiming = false }

        do {
            let conversationIDs = try await claimService.claim(token: token)
            if let first = conversationIDs.first {
                lastClaimedConversationID = first
                router.openConversation(first)
            }
        } catch is CancellationError {
            return
        } catch {
            AppLogger.booking.error(
                "External booking claim failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
