import Foundation

/// Claims a booking request submitted by the signed-in user from outside the
/// app (App Clip or web form). Backed by the `claim-external-booking` edge
/// function, which validates that the authenticated user's email matches the
/// email on file for the invite, then links the conversation to their account.
protocol ExternalBookingClaimServiceProtocol: Sendable {
    /// Attempts to claim a specific invite token, if provided, and/or sweeps
    /// any pending invites that match the signed-in user's email. Returns the
    /// conversation ids that were claimed in this call.
    func claim(token: String?) async throws -> [UUID]
}

nonisolated struct ExternalBookingClaimResponse: Codable, Hashable, Sendable {
    let conversationIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case conversationIDs = "conversation_ids"
    }
}
