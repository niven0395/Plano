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
    let budgetLabel: String?
    let startTime: String?
    let endTime: String?
    let durationHours: Double?
    let venueSetting: String?
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
        case startTime = "start_time"
        case endTime = "end_time"
        case durationHours = "duration_hours"
        case venueSetting = "venue_setting"
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
        startTime = event.startTime.map(Self.formatTime)
        endTime = event.endTime.map(Self.formatTime)
        durationHours = event.durationHours
        venueSetting = event.venueSetting.rawValue
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
            startTime: startTime.flatMap(Self.parseTime),
            endTime: endTime.flatMap(Self.parseTime),
            durationHours: durationHours,
            venueSetting: VenueSetting(rawValue: venueSetting ?? "tbd") ?? .tbd,
            planningNote: planningNote,
            progress: progress,
            stage: BookingStage.fromDatabaseValue(stage),
            eventStage: EventStage(rawValue: eventStage ?? "planning") ?? .planning
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static func parseTime(_ string: String) -> Date? {
        timeFormatter.date(from: string)
    }
}
