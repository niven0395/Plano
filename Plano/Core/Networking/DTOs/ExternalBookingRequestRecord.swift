import Foundation

nonisolated struct ExternalBookingRequestRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let vendorID: UUID
    let firstName: String
    let lastName: String
    let email: String
    let eventDate: Date
    let guestCount: Int?
    let note: String
    let intakeAnswers: [LeadIntakeAnswer]
    let source: String
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vendorID = "vendor_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case eventDate = "event_date"
        case guestCount = "guest_count"
        case note
        case intakeAnswers = "intake_answers"
        case source
        case status
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vendorID = try container.decode(UUID.self, forKey: .vendorID)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        email = try container.decode(String.self, forKey: .email)
        guard let decodedEventDate = try PostgresDateValueDecoder.decodeIfPresent(forKey: .eventDate, from: container) else {
            throw DecodingError.valueNotFound(
                Date.self,
                .init(codingPath: [CodingKeys.eventDate], debugDescription: "event_date is required")
            )
        }
        eventDate = decodedEventDate
        guestCount = try container.decodeIfPresent(Int.self, forKey: .guestCount)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        intakeAnswers = (try? container.decode([LeadIntakeAnswer].self, forKey: .intakeAnswers)) ?? []
        source = try container.decode(String.self, forKey: .source)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try PostgresDateValueDecoder.decodeIfPresent(forKey: .createdAt, from: container) ?? Date()
    }
}

nonisolated struct ExternalBookingAcceptResult: Codable, Sendable {
    let requestID: UUID
    let conversationID: UUID
    let bookingID: UUID
    let inviteToken: String

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case conversationID = "conversation_id"
        case bookingID = "booking_id"
        case inviteToken = "invite_token"
    }
}
