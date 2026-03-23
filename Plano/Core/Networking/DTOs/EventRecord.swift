import Foundation

nonisolated struct EventRecord: Codable, Hashable {
    let id: UUID
    let hostID: UUID
    let title: String
    let eventType: String
    let date: Date
    let venue: String
    let city: String
    let guestCount: String
    let budgetLabel: String
    let planningNote: String
    let progress: Double
    let stage: String
    let eventStage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case hostID = "host_id"
        case title
        case eventType = "event_type"
        case date
        case venue
        case city
        case guestCount = "guest_count"
        case budgetLabel = "budget_label"
        case planningNote = "planning_note"
        case progress
        case stage
        case eventStage = "event_stage"
    }

    init(event: PartyEvent, hostID: UUID) {
        id = event.id
        self.hostID = hostID
        title = event.title
        eventType = event.type.rawValue
        date = event.date
        venue = event.venue
        city = event.city
        guestCount = String(event.guestCount)
        budgetLabel = event.budgetLabel
        planningNote = event.planningNote
        progress = event.progress
        stage = event.stage.rawValue
        eventStage = event.eventStage.rawValue
    }

    func makePartyEvent() -> PartyEvent {
        PartyEvent(
            id: id,
            title: title,
            type: EventType(rawValue: eventType) ?? .engagement,
            date: date,
            venue: venue,
            city: city,
            guestCount: GuestCountValue.resolve(from: guestCount),
            budgetLabel: budgetLabel,
            planningNote: planningNote,
            progress: progress,
            stage: BookingStage.fromDatabaseValue(stage),
            eventStage: EventStage(rawValue: eventStage ?? "planning") ?? .planning
        )
    }
}
