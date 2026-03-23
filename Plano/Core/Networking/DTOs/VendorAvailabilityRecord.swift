import Foundation

struct VendorAvailabilityRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let vendorID: UUID
    let rawDate: String
    let status: String
    let note: String?
    let bookingID: UUID?
    let conversationID: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case vendorID = "vendor_id"
        case rawDate = "date"
        case status
        case note
        case bookingID = "booking_id"
        case conversationID = "conversation_id"
        case createdAt = "created_at"
    }

    var date: Date? {
        Self.dateFormatter.date(from: rawDate)
    }

    init(
        id: UUID = UUID(),
        vendorID: UUID,
        rawDate: String,
        status: String,
        note: String? = nil,
        bookingID: UUID? = nil,
        conversationID: UUID? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.vendorID = vendorID
        self.rawDate = rawDate
        self.status = status
        self.note = note
        self.bookingID = bookingID
        self.conversationID = conversationID
        self.createdAt = createdAt
    }

    init(
        id: UUID = UUID(),
        vendorID: UUID,
        date: Date,
        status: String,
        note: String? = nil,
        bookingID: UUID? = nil,
        conversationID: UUID? = nil,
        createdAt: Date? = nil
    ) {
        self.init(
            id: id,
            vendorID: vendorID,
            rawDate: Self.dateFormatter.string(from: date),
            status: status,
            note: note,
            bookingID: bookingID,
            conversationID: conversationID,
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
