import Foundation
import OSLog

/// Fallback for environments where Supabase is not configured (previews,
/// tests, missing credentials). Returns an empty claim result instead of
/// failing — the claim flow silently no-ops until the real backend is wired.
struct UnavailableExternalBookingClaimService: ExternalBookingClaimServiceProtocol {
    let message: String

    func claim(token: String?) async throws -> [UUID] {
        AppLogger.networking.notice(
            "ExternalBookingClaim: \(message, privacy: .public) (token provided: \(token != nil, privacy: .public))"
        )
        return []
    }
}
