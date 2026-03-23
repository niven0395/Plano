import Foundation

protocol EventServiceProtocol {
    func fetchEvents() async throws -> [PartyEvent]
    func createEvent(from draft: EventDraft) async throws -> PartyEvent
    func updateEventVenue(_ venue: String, eventID: UUID) async throws -> PartyEvent
    func deleteEvent(eventID: UUID) async throws -> DeletionResult
}
