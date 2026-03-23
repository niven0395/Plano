import Foundation
#if canImport(Supabase)
import Supabase

actor LivePlannedVendorService: PlannedVendorServiceProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchPlannedVendors(eventID: UUID) async throws -> [PlannedVendorRecord] {
        try await client.from("planned_vendors")
            .select()
            .eq("event_id", value: eventID)
            .neq("status", value: "removed")
            .order("created_at")
            .execute()
            .value
    }

    func fetchAllPlannedVendors(eventIDs: [UUID]) async throws -> [PlannedVendorRecord] {
        guard !eventIDs.isEmpty else { return [] }

        return try await client.from("planned_vendors")
            .select()
            .in("event_id", values: eventIDs)
            .neq("status", value: "removed")
            .order("created_at")
            .execute()
            .value
    }

    func planVendor(eventID: UUID, vendorID: UUID, category: VendorCategory) async throws -> PlannedVendorRecord {
        let record = PlannedVendorRecord(
            eventID: eventID,
            vendorID: vendorID,
            category: category.rawValue,
            status: PlannedVendorStatus.planned.rawValue,
            availabilityCheckedAt: .now
        )

        return try await client.from("planned_vendors")
            .upsert(record, onConflict: "event_id,vendor_id")
            .select()
            .single()
            .execute()
            .value
    }

    func removePlannedVendor(eventID: UUID, vendorID: UUID) async throws {
        try await client.from("planned_vendors")
            .update(["status": "removed"])
            .eq("event_id", value: eventID)
            .eq("vendor_id", value: vendorID)
            .execute()
    }

    func updateStatus(eventID: UUID, vendorID: UUID, status: PlannedVendorStatus) async throws {
        try await client.from("planned_vendors")
            .update(["status": status.rawValue])
            .eq("event_id", value: eventID)
            .eq("vendor_id", value: vendorID)
            .execute()
    }

    func batchUpdateStatus(eventID: UUID, vendorIDs: [UUID], status: PlannedVendorStatus) async throws {
        guard !vendorIDs.isEmpty else { return }

        try await client.from("planned_vendors")
            .update(["status": status.rawValue])
            .eq("event_id", value: eventID)
            .in("vendor_id", values: vendorIDs)
            .execute()
    }
}
#else
actor LivePlannedVendorService: PlannedVendorServiceProtocol {
    init(client: Any? = nil) {}

    func fetchPlannedVendors(eventID: UUID) async throws -> [PlannedVendorRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchAllPlannedVendors(eventIDs: [UUID]) async throws -> [PlannedVendorRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func planVendor(eventID: UUID, vendorID: UUID, category: VendorCategory) async throws -> PlannedVendorRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func removePlannedVendor(eventID: UUID, vendorID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func updateStatus(eventID: UUID, vendorID: UUID, status: PlannedVendorStatus) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func batchUpdateStatus(eventID: UUID, vendorIDs: [UUID], status: PlannedVendorStatus) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }
}
#endif
