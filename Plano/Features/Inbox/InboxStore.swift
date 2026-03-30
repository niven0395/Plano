import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class InboxStore {
    private static let draftsKey = "plano.inbox.drafts"
    private static let archivedKey = "plano.inbox.archived"
    static let messagesPerPage = 30

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let relativeFormatter: RelativeDateTimeFormatter
    @ObservationIgnored let sessionStore: SessionStore
    @ObservationIgnored let bookingService: any BookingServiceProtocol
    @ObservationIgnored let messagingService: any MessagingServiceProtocol
    @ObservationIgnored let vendorProfileService: any VendorProfileServiceProtocol
    @ObservationIgnored var analyticsService: any AnalyticsServiceProtocol = UnavailableAnalyticsService(message: "")
    @ObservationIgnored private var hasLoadedIdentityKey: String?
    @ObservationIgnored private var offlineSendQueue: OfflineSendQueue?
    @ObservationIgnored var typingDebounceTimers: [UUID: Task<Void, Never>] = [:]
    /// Tracks the most recent message timestamp per conversation for catch-up sync.
    @ObservationIgnored var lastRealtimeMessageAt: [UUID: Date] = [:]
    /// Local SwiftData cache for offline message persistence.
    @ObservationIgnored var messageCacheManager: MessageCacheManager?
    /// In-flight conversation creation tasks keyed by "vendorID-eventID" to prevent duplicate requests.
    @ObservationIgnored var conversationCreationTasks: [String: Task<UUID, Error>] = [:]

    // MARK: - Internal managers

    @ObservationIgnored let draftManager: InboxDraftManager
    @ObservationIgnored let archiveManager: InboxArchiveManager
    @ObservationIgnored let messageSender: ConversationMessageSender
    @ObservationIgnored let bookingCoordinator: ConversationBookingCoordinator

    // MARK: - Observable state

    var conversations: [ConversationThread] = []
    var filter: InboxFilter = .all
    var loadingState: LoadingState = .idle
    var isRefreshing = false
    var confirmingPaymentIDs: Set<UUID> {
        get { bookingCoordinator.confirmingPaymentIDs }
        set { bookingCoordinator.confirmingPaymentIDs = newValue }
    }
    var confirmPaymentError: String? {
        get { bookingCoordinator.confirmPaymentError }
        set { bookingCoordinator.confirmPaymentError = newValue }
    }
    var bookingActionError: String? {
        get { bookingCoordinator.bookingActionError }
        set { bookingCoordinator.bookingActionError = newValue }
    }
    var draftsByKey: [String: String] {
        get { draftManager.draftsByKey }
        set { draftManager.setDrafts(newValue) }
    }
    var archivedConversationKeys: Set<String> {
        get { archiveManager.archivedConversationKeys }
        set { archiveManager.setArchivedKeys(newValue) }
    }
    var typingSenders: [UUID: ChatMessageSender] = [:]
    var vendorProfilesByID: [UUID: VendorProfile] = [:]
    var dateConflictsByConversation: [UUID: [DateConflict]] = [:]
    var bookingRequestsByConversation: [UUID: BookingRequestRecord] = [:]
    var vendorNotes: [UUID: String] = [:]

    var realtimeManager: RealtimeManager?
    var networkMonitor: NetworkMonitor?
    @ObservationIgnored var onStageChanged: (() -> Void)?

    init(
        bookingService: any BookingServiceProtocol,
        messagingService: any MessagingServiceProtocol,
        vendorProfileService: any VendorProfileServiceProtocol,
        sessionStore: SessionStore,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.sessionStore = sessionStore
        self.bookingService = bookingService
        self.messagingService = messagingService
        self.vendorProfileService = vendorProfileService

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        relativeFormatter = formatter

        // Initialise managers
        draftManager = InboxDraftManager(defaults: defaults)
        archiveManager = InboxArchiveManager(defaults: defaults)
        bookingCoordinator = ConversationBookingCoordinator(
            bookingService: bookingService,
            sessionStore: sessionStore
        )
        messageSender = ConversationMessageSender(messagingService: messagingService)

        // Wire message sender callbacks now that self is fully initialised
        messageSender.offlineSendQueueProvider = { [weak self] in self?.offlineSendQueue }
        messageSender.networkMonitorProvider = { [weak self] in self?.networkMonitor }
        messageSender.currentUserIDProvider = { [weak sessionStore] in sessionStore?.currentUserID }
        messageSender.onAppendMessage = { [weak self] message, conversationID, unreadRole in
            self?.appendMessage(message, to: conversationID, incrementUnreadFor: unreadRole)
        }
        messageSender.onReplaceOptimistic = { [weak self] clientID, conversationID, message in
            self?.replaceOptimisticMessage(clientID: clientID, in: conversationID, with: message)
        }
        messageSender.onUpdateStatus = { [weak self] clientID, conversationID, status in
            self?.updateMessageStatus(clientID: clientID, in: conversationID, to: status)
        }
        messageSender.onSetLoadingState = { [weak self] state in
            self?.loadingState = state
        }
    }

    // MARK: - Offline queue & realtime

    func configureOfflineQueue() {
        guard offlineSendQueue == nil else { return }
        offlineSendQueue = OfflineSendQueue(
            messagingService: messagingService,
            onMessageSent: { [weak self] conversationID, clientID, record in
                await MainActor.run { [weak self] in
                    self?.handleOfflineMessageSent(conversationID: conversationID, clientID: clientID, record: record)
                }
            },
            onMessageFailed: { [weak self] conversationID, clientID in
                await MainActor.run { [weak self] in
                    self?.handleOfflineMessageFailed(conversationID: conversationID, clientID: clientID)
                }
            }
        )
    }

    func configureRealtimeCallbacks() {
        realtimeManager?.onMessageReceived = { [weak self] record in
            Task { @MainActor [weak self] in
                self?.handleRealtimeMessage(record)
            }
        }
        realtimeManager?.onConversationUpdated = { [weak self] record in
            Task { @MainActor [weak self] in
                self?.handleRealtimeConversationUpdate(record)
            }
        }
        realtimeManager?.onMessageStatusUpdated = { [weak self] messageID, status in
            Task { @MainActor [weak self] in
                self?.handleRealtimeMessageStatusUpdate(messageID: messageID, status: status)
            }
        }
        realtimeManager?.onTypingReceived = { [weak self] conversationID, sender in
            Task { @MainActor [weak self] in
                self?.typingSenders[conversationID] = sender
            }
        }
        realtimeManager?.onTypingStopped = { [weak self] conversationID in
            Task { @MainActor [weak self] in
                self?.typingSenders.removeValue(forKey: conversationID)
            }
        }
        realtimeManager?.onReconnected = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.catchUpAfterReconnect()
            }
        }
    }

    func drainOfflineQueue() {
        Task {
            await offlineSendQueue?.drain()
        }
    }

    // MARK: - Conversation loading

    func loadConversationsIfNeeded(for role: UserRole) async {
        guard let userID = sessionStore.currentUserID else {
            reset()
            return
        }

        let identityKey = "\(role.rawValue).\(userID.uuidString)"
        guard hasLoadedIdentityKey != identityKey else { return }
        await loadConversations(for: role)
    }

    func loadConversations(for role: UserRole) async {
        guard let userID = sessionStore.currentUserID else {
            reset()
            return
        }

        let identityKey = "\(role.rawValue).\(userID.uuidString)"
        if conversations.isEmpty {
            loadingState = .loading
        } else {
            isRefreshing = true
        }

        do {
            let records: [ConversationRecord]
            switch role {
            case .host:
                records = try await bookingService.fetchConversations(hostID: userID)
            case .vendor:
                records = try await bookingService.fetchVendorConversations(vendorID: userID)
            }

            AppLogger.booking.info("loadConversations(\(role.rawValue, privacy: .public)): fetched \(records.count) records for userID=\(userID.uuidString, privacy: .public)")
            for record in records {
                AppLogger.booking.info("  conv=\(record.id.uuidString.prefix(8), privacy: .public) stage=\(record.stage, privacy: .public) vendorID=\(record.vendorID.uuidString.prefix(8), privacy: .public) hostID=\(record.hostID.uuidString.prefix(8), privacy: .public)")
            }

            let conversationIDs = records.map(\.id)
            let bookingRequests = try await bookingService.fetchBookingRequests(conversationIDs: conversationIDs)
            let bookings = try await bookingService.fetchBookings(conversationIDs: conversationIDs)
            await loadVendorProfiles(for: Set(records.map(\.vendorID)))

            let requestByConversation = latestBookingRequests(bookingRequests)
            let bookingByConversation = latestBookings(bookings)
            bookingRequestsByConversation = requestByConversation

            let rebuiltConversations = records.map { record in
                let request = requestByConversation[record.id]
                let booking = bookingByConversation[record.id]

                let paymentRequest: PaymentRequest? = booking.flatMap { b in
                    guard let amountCents = b.paymentRequestedAmountCents else { return nil }
                    let status: PaymentRequestStatus = b.paymentConfirmedAt != nil ? .paid : .pending
                    return PaymentRequest(
                        amountCents: amountCents,
                        note: b.paymentRequestNote ?? "",
                        requestedAt: b.paymentRequestedAt,
                        status: status,
                        paymentType: b.paymentType.flatMap { PaymentType(rawValue: $0) } ?? .deposit
                    )
                }

                let cancellationRequestedByRole: UserRole? = booking?.cancellationRequestedBy.flatMap { requestedBy in
                    if requestedBy == record.hostID { return .host }
                    if requestedBy == record.vendorID { return .vendor }
                    return nil
                }

                return ConversationThread(
                    id: record.id,
                    eventID: record.eventID,
                    eventDate: booking?.eventDate ?? request?.eventDate,
                    vendorID: record.vendorID,
                    hostUserID: record.hostID,
                    hostName: record.hostDisplayName,
                    vendorName: record.vendorDisplayName,
                    vendorCategory: VendorCategory.fromDatabaseValue(record.vendorCategory) ?? .entertainer,
                    eventTitle: record.eventTitle ?? "Direct inquiry",
                    eventDateLabel: record.eventDateLabel ?? "Date pending",
                    eventContextLine: record.eventContextLine ?? "Guest count pending",
                    stage: BookingStage.fromDatabaseValue(record.stage),
                    bookingEventDate: booking?.eventDate ?? request?.eventDate,
                    paymentRequest: paymentRequest,
                    messages: [],
                    lastActivityAt: record.lastActivityAt,
                    hostUnreadCount: record.hostUnreadCount ?? 0,
                    vendorUnreadCount: record.vendorUnreadCount ?? 0,
                    hasLoadedInitialMessages: false,
                    hasOlderMessages: false,
                    cancellationRequestDeadline: booking?.cancellationRequestDeadline,
                    cancellationRequestedByRole: cancellationRequestedByRole,
                    cancellationDeclinedAt: booking?.cancellationDeclinedAt
                )
            }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }

            conversations = rebuiltConversations
            if role == .vendor {
                await refreshVendorDateConflicts(for: rebuiltConversations)
            } else {
                dateConflictsByConversation = [:]
            }

            let conversationIDSet = Set(conversationIDs)
            realtimeManager?.subscribe(userID: userID, role: role, conversationIDs: conversationIDSet)

            hasLoadedIdentityKey = identityKey
            isRefreshing = false
            loadingState = .loaded

            drainOfflineQueue()
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            isRefreshing = false
            loadingState = .failed(error.localizedDescription)
            AppLogger.booking.error("Failed to load conversations: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Vendor notes

    func loadVendorNote(for conversationID: UUID) async {
        do {
            let content = try await bookingService.fetchVendorNote(conversationID: conversationID)
            vendorNotes[conversationID] = content ?? ""
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            AppLogger.booking.error("Failed to load vendor note: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveVendorNote(for conversationID: UUID, content: String) async {
        vendorNotes[conversationID] = content
        do {
            try await bookingService.saveVendorNote(conversationID: conversationID, content: content)
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            AppLogger.booking.error("Failed to save vendor note: \(error.localizedDescription, privacy: .public)")
        }
    }

    func reset() {
        conversations = []
        vendorProfilesByID = [:]
        dateConflictsByConversation = [:]
        bookingRequestsByConversation = [:]
        vendorNotes = [:]
        typingSenders = [:]
        hasLoadedIdentityKey = nil
        loadingState = .idle
    }
}
