import Foundation
#if canImport(Supabase)
import Supabase

actor LiveEventService: EventServiceProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchEvents() async throws -> [PartyEvent] {
        let session = try await client.auth.session
        let records: [EventRecord] = try await client.from("events")
            .select()
            .eq("host_id", value: session.user.id)
            .execute()
            .value

        return records
            .map { $0.makePartyEvent() }
            .sorted { $0.date < $1.date }
    }

    func createEvent(from draft: EventDraft) async throws -> PartyEvent {
        let session = try await client.auth.session
        let record = EventRecord(
            event: draft.makeEvent(),
            hostID: session.user.id
        )

        let createdRecord: EventRecord = try await client.from("events")
            .insert(record)
            .select()
            .single()
            .execute()
            .value

        return createdRecord.makePartyEvent()
    }

    func updateEventVenue(_ venue: String, eventID: UUID) async throws -> PartyEvent {
        let session = try await client.auth.session
        let normalizedVenue = venue.trimmingCharacters(in: .whitespacesAndNewlines)

        let updatedRecord: EventRecord = try await client.from("events")
            .update(["venue": normalizedVenue])
            .eq("id", value: eventID)
            .eq("host_id", value: session.user.id)
            .select()
            .single()
            .execute()
            .value

        return updatedRecord.makePartyEvent()
    }

    func deleteEvent(eventID: UUID) async throws -> DeletionResult {
        try await client.rpc(
            "delete_event_with_cancellations",
            params: ["p_event_id": eventID.uuidString]
        )
        .execute()
        .value
    }
}
#else
actor LiveEventService: EventServiceProtocol {
    init(client: Any? = nil) {}

    func fetchEvents() async throws -> [PartyEvent] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func createEvent(from draft: EventDraft) async throws -> PartyEvent {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func updateEventVenue(_ venue: String, eventID: UUID) async throws -> PartyEvent {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func deleteEvent(eventID: UUID) async throws -> DeletionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }
}
#endif
