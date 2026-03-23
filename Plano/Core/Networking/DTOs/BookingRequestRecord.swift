import Foundation

nonisolated struct BookingRequestRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let conversationID: UUID
    let title: String?
    let budgetLabel: String?
    let responseWindowLabel: String?
    let requestedServices: [String]?
    let note: String
    let guestCountLabel: String?
    let eventDate: Date?
    let requestedTimeStart: String?
    let requestedTimeEnd: String?
    let intakeAnswers: [LeadIntakeAnswer]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case title
        case budgetLabel = "budget_label"
        case responseWindowLabel = "response_window_label"
        case requestedServices = "requested_services"
        case note
        case guestCountLabel = "guest_count_label"
        case eventDate = "event_date"
        case requestedTimeStart = "requested_time_start"
        case requestedTimeEnd = "requested_time_end"
        case intakeAnswers = "intake_answers"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        conversationID: UUID,
        title: String? = nil,
        budgetLabel: String? = nil,
        responseWindowLabel: String? = nil,
        requestedServices: [String]? = nil,
        note: String = "",
        guestCountLabel: String? = nil,
        eventDate: Date? = nil,
        requestedTimeStart: String? = nil,
        requestedTimeEnd: String? = nil,
        intakeAnswers: [LeadIntakeAnswer]? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.title = title
        self.budgetLabel = budgetLabel
        self.responseWindowLabel = responseWindowLabel
        self.requestedServices = requestedServices
        self.note = note
        self.guestCountLabel = guestCountLabel
        self.eventDate = eventDate
        self.requestedTimeStart = requestedTimeStart
        self.requestedTimeEnd = requestedTimeEnd
        self.intakeAnswers = intakeAnswers
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        conversationID = try container.decode(UUID.self, forKey: .conversationID)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        budgetLabel = try container.decodeIfPresent(String.self, forKey: .budgetLabel)
        responseWindowLabel = try container.decodeIfPresent(String.self, forKey: .responseWindowLabel)
        requestedServices = try container.decodeIfPresent([String].self, forKey: .requestedServices)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        guestCountLabel = try container.decodeIfPresent(String.self, forKey: .guestCountLabel)
        eventDate = try PostgresDateValueDecoder.decodeIfPresent(forKey: .eventDate, from: container)
        requestedTimeStart = try container.decodeIfPresent(String.self, forKey: .requestedTimeStart)
        requestedTimeEnd = try container.decodeIfPresent(String.self, forKey: .requestedTimeEnd)
        intakeAnswers = try container.decodeIfPresent([LeadIntakeAnswer].self, forKey: .intakeAnswers)
        createdAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .createdAt, from: container)
    }
}
