import Foundation
#if canImport(Supabase)
import Supabase

actor LiveExternalBookingClaimService: ExternalBookingClaimServiceProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func claim(token: String?) async throws -> [UUID] {
        _ = try await client.auth.session

        struct Payload: Encodable {
            let token: String?
        }

        let options = FunctionInvokeOptions(body: Payload(token: token))
        let response: ExternalBookingClaimResponse = try await client.functions.invoke(
            "claim-external-booking",
            options: options
        )
        return response.conversationIDs
    }
}
#endif
