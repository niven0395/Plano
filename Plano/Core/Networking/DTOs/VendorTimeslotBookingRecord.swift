import Foundation

nonisolated struct VendorTimeslotBookingRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let vendorID: UUID
    let rawDate: String
    let startTime: String
    let endTime: String
    let status: String
    let bookingID: UUID?
    let conversationID: UUID?
    let hostID: UUID?
    let note: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case vendorID = "vendor_id"
        case rawDate = "date"
        case startTime = "start_time"
        case endTime = "end_time"
        case status
        case bookingID = "booking_id"
        case conversationID = "conversation_id"
        case hostID = "host_id"
        case note
        case createdAt = "created_at"
    }

    var date: Date? {
        Self.dateFormatter.date(from: rawDate)
    }

    init(
        id: UUID = UUID(),
        vendorID: UUID,
        rawDate: String,
        startTime: String,
        endTime: String,
        status: String,
        bookingID: UUID? = nil,
        conversationID: UUID? = nil,
        hostID: UUID? = nil,
        note: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.vendorID = vendorID
        self.rawDate = rawDate
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.bookingID = bookingID
        self.conversationID = conversationID
        self.hostID = hostID
        self.note = note
        self.createdAt = createdAt
    }

    init(
        id: UUID = UUID(),
        vendorID: UUID,
        date: Date,
        startTime: String,
        endTime: String,
        status: String,
        bookingID: UUID? = nil,
        conversationID: UUID? = nil,
        hostID: UUID? = nil,
        note: String? = nil,
        createdAt: Date? = nil
    ) {
        self.init(
            id: id,
            vendorID: vendorID,
            rawDate: Self.dateFormatter.string(from: date),
            startTime: startTime,
            endTime: endTime,
            status: status,
            bookingID: bookingID,
            conversationID: conversationID,
            hostID: hostID,
            note: note,
            createdAt: createdAt
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
