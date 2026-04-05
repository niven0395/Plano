import Foundation

enum ChatMessageSender: String, Hashable {
    case host
    case vendor
    case system

    var userRole: UserRole? {
        switch self {
        case .host:
            .host
        case .vendor:
            .vendor
        case .system:
            nil
        }
    }
}

enum ConversationError: Error, LocalizedError {
    case selfMessaging

    var errorDescription: String? {
        switch self {
        case .selfMessaging:
            "You cannot start a conversation with your own vendor profile."
        }
    }
}

enum ChatMessageKind: Hashable {
    case text
    case system
    case paymentRequest
    case attachment
}

struct ChatMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    let sender: ChatMessageSender
    let body: String
    let sentAt: Date
    let kind: ChatMessageKind
    var status: MessageDeliveryStatus
    let clientID: UUID?
    var attachments: [MessageAttachment]
    let sequenceNumber: Int?

    init(
        id: UUID = UUID(),
        sender: ChatMessageSender,
        body: String,
        sentAt: Date,
        kind: ChatMessageKind = .text,
        status: MessageDeliveryStatus = .sent,
        clientID: UUID? = nil,
        attachments: [MessageAttachment] = [],
        sequenceNumber: Int? = nil
    ) {
        self.id = id
        self.sender = sender
        self.body = body
        self.sentAt = sentAt
        self.kind = kind
        self.status = status
        self.clientID = clientID
        self.attachments = attachments
        self.sequenceNumber = sequenceNumber
    }

    var previewText: String {
        switch kind {
        case .text, .system, .paymentRequest:
            body
        case .attachment:
            attachments.isEmpty ? body : "Sent \(attachments.count) attachment\(attachments.count == 1 ? "" : "s")"
        }
    }

    var isSending: Bool { status == .sending }
    var hasFailed: Bool { status == .failed }
}

struct ConversationSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let counterpartName: String
    let contextTitle: String
    let preview: String
    let timeLabel: String
    let unreadCount: Int
    let stage: BookingStage

    init(
        id: UUID = UUID(),
        counterpartName: String,
        contextTitle: String,
        preview: String,
        timeLabel: String,
        unreadCount: Int,
        stage: BookingStage
    ) {
        self.id = id
        self.counterpartName = counterpartName
        self.contextTitle = contextTitle
        self.preview = preview
        self.timeLabel = timeLabel
        self.unreadCount = unreadCount
        self.stage = stage
    }
}

struct ConversationThread: Identifiable, Hashable, Sendable {
    let id: UUID
    var eventID: UUID?
    let eventDate: Date?
    let vendorID: UUID
    let hostUserID: UUID
    let hostName: String
    let vendorName: String
    let vendorCategory: VendorCategory
    let eventTitle: String
    let eventDateLabel: String
    let eventContextLine: String
    var stage: BookingStage
    var bookingEventDate: Date?
    var paymentRequest: PaymentRequest?
    var messages: [ChatMessage]
    var lastActivityAt: Date
    var hostUnreadCount: Int
    var vendorUnreadCount: Int
    var hasLoadedInitialMessages: Bool
    var hasOlderMessages: Bool
    var isLoadingMessages: Bool
    var cancellationRequestDeadline: Date?
    var cancellationRequestedByRole: UserRole?
    var cancellationDeclinedAt: Date?
    let venueSettingLabel: String?
    let timeRangeLabel: String?

    var isHostCancelled: Bool {
        stage == .cancelled && cancellationRequestedByRole == .host
    }

    init(
        id: UUID = UUID(),
        eventID: UUID?,
        eventDate: Date? = nil,
        vendorID: UUID,
        hostUserID: UUID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001") ?? UUID(),
        hostName: String,
        vendorName: String,
        vendorCategory: VendorCategory,
        eventTitle: String,
        eventDateLabel: String,
        eventContextLine: String,
        stage: BookingStage,
        bookingEventDate: Date? = nil,
        paymentRequest: PaymentRequest? = nil,
        messages: [ChatMessage],
        lastActivityAt: Date,
        hostUnreadCount: Int,
        vendorUnreadCount: Int,
        hasLoadedInitialMessages: Bool = false,
        hasOlderMessages: Bool = false,
        isLoadingMessages: Bool = false,
        cancellationRequestDeadline: Date? = nil,
        cancellationRequestedByRole: UserRole? = nil,
        cancellationDeclinedAt: Date? = nil,
        venueSettingLabel: String? = nil,
        timeRangeLabel: String? = nil
    ) {
        self.id = id
        self.eventID = eventID
        self.eventDate = eventDate
        self.vendorID = vendorID
        self.hostUserID = hostUserID
        self.hostName = hostName
        self.vendorName = vendorName
        self.vendorCategory = vendorCategory
        self.eventTitle = eventTitle
        self.eventDateLabel = eventDateLabel
        self.eventContextLine = eventContextLine
        self.stage = stage
        self.bookingEventDate = bookingEventDate
        self.paymentRequest = paymentRequest
        self.messages = messages
        self.lastActivityAt = lastActivityAt
        self.hostUnreadCount = hostUnreadCount
        self.vendorUnreadCount = vendorUnreadCount
        self.hasLoadedInitialMessages = hasLoadedInitialMessages
        self.hasOlderMessages = hasOlderMessages
        self.isLoadingMessages = isLoadingMessages
        self.cancellationRequestDeadline = cancellationRequestDeadline
        self.cancellationRequestedByRole = cancellationRequestedByRole
        self.cancellationDeclinedAt = cancellationDeclinedAt
        self.venueSettingLabel = venueSettingLabel
        self.timeRangeLabel = timeRangeLabel
    }

    var lastMessagePreview: String {
        messages.last?.previewText ?? "No messages yet."
    }

    var resolvedEventDate: Date? {
        if let bookingEventDate {
            return bookingEventDate
        }

        if let eventDate {
            return eventDate
        }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEEE, MMMM d"
        guard let partialDate = formatter.date(from: eventDateLabel) else { return nil }
        var components = Calendar.current.dateComponents([.month, .day], from: partialDate)
        components.year = Calendar.current.component(.year, from: .now)
        return Calendar.current.date(from: components)
    }

    func counterpartName(for role: UserRole) -> String {
        switch role {
        case .host:
            vendorName
        case .vendor:
            hostName
        }
    }

    func unreadCount(for role: UserRole) -> Int {
        switch role {
        case .host:
            hostUnreadCount
        case .vendor:
            vendorUnreadCount
        }
    }

    func summary(for role: UserRole, formatter: RelativeDateTimeFormatter) -> ConversationSummary {
        ConversationSummary(
            id: id,
            counterpartName: counterpartName(for: role),
            contextTitle: vendorCategory.singularTitle,
            preview: lastMessagePreview,
            timeLabel: formatter.localizedString(for: lastActivityAt, relativeTo: .now),
            unreadCount: unreadCount(for: role),
            stage: stage
        )
    }
}
