import Foundation
#if canImport(Supabase)
import Supabase

actor LiveVendorSearchService: VendorSearchServiceProtocol {
    private let client: SupabaseClient
    private static let tokenExpiryBuffer: TimeInterval = 30

    init(client: SupabaseClient) {
        self.client = client
    }

    private func ensureFreshToken() async throws {
        let session = try await client.auth.session
        let expiresAt = Date(timeIntervalSince1970: session.expiresAt)
        if expiresAt.timeIntervalSinceNow < Self.tokenExpiryBuffer {
            _ = try await client.auth.refreshSession()
        }
    }

    func searchVendors(matching request: VendorSearchRequest) async throws -> [VendorProfileRecord] {
        try await ensureFreshToken()

        let payload = VendorSearchPayload(
            query: request.normalizedText.isEmpty ? nil : request.text,
            category: request.category?.rawValue,
            city: request.city,
            eventDate: request.eventDate.map { Self.makeDateOnlyFormatter().string(from: $0) },
            limit: request.limit,
            offset: 0
        )

        let results: [VendorProfileRecord] = try await client.functions.invoke(
            "vendor-search",
            options: FunctionInvokeOptions(body: payload),
            decoder: ISO8601Decoding.decoder
        )
        return results
    }

    func fetchSavedVendorIDs() async throws -> Set<UUID> {
        let session = try await client.auth.session
        let records: [SavedVendorRecord] = try await client.from("saved_vendors")
            .select()
            .eq("host_id", value: session.user.id)
            .execute()
            .value

        return Set(records.map(\.vendorID))
    }

    func saveVendor(_ vendorID: UUID) async throws {
        let session = try await client.auth.session
        let record = SavedVendorRecord(hostID: session.user.id, vendorID: vendorID)

        try await client.from("saved_vendors")
            .upsert(record, onConflict: "host_id,vendor_id")
            .execute()
    }

    func unsaveVendor(_ vendorID: UUID) async throws {
        let session = try await client.auth.session

        try await client.from("saved_vendors")
            .delete()
            .eq("host_id", value: session.user.id)
            .eq("vendor_id", value: vendorID)
            .execute()
    }

    private static func makeDateOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

private struct VendorSearchPayload: Encodable {
    let query: String?
    let category: String?
    let city: String?
    let eventDate: String?
    let limit: Int
    let offset: Int

    enum CodingKeys: String, CodingKey {
        case query, category, city
        case eventDate = "event_date"
        case limit, offset
    }
}
#else
actor LiveVendorSearchService: VendorSearchServiceProtocol {
    init(client: Any? = nil) {}

    func searchVendors(matching request: VendorSearchRequest) async throws -> [VendorProfileRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchSavedVendorIDs() async throws -> Set<UUID> {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func saveVendor(_ vendorID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func unsaveVendor(_ vendorID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }
}
#endif
