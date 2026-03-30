import Foundation
import Observation
import OSLog
#if canImport(Supabase)
import Supabase
#endif

enum RealtimeConnectionState: String, Sendable {
    case connected
    case connecting
    case disconnected
}

@MainActor
@Observable
final class RealtimeManager {
    private(set) var connectionState: RealtimeConnectionState = .disconnected
    private(set) var hasEverConnected = false

    @ObservationIgnored private var currentUserID: UUID?
    @ObservationIgnored private var currentRole: UserRole?
    @ObservationIgnored private var subscribedConversationIDs: Set<UUID> = []
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var messageListenerTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var messageStatusListenerTask: Task<Void, Never>?
    @ObservationIgnored private var conversationListenerTask: Task<Void, Never>?
    @ObservationIgnored private var typingListenerTask: Task<Void, Never>?

    @ObservationIgnored var onMessageReceived: ((MessageRecord) -> Void)?
    /// Called when a message status changes (e.g. sent → delivered → read).
    @ObservationIgnored var onMessageStatusUpdated: ((UUID, String) -> Void)?
    @ObservationIgnored var onConversationUpdated: ((ConversationRecord) -> Void)?
    @ObservationIgnored var onTypingReceived: ((UUID, ChatMessageSender) -> Void)?
    @ObservationIgnored var onTypingStopped: ((UUID) -> Void)?
    /// Called after reconnection so the caller can fetch messages missed during disconnection.
    @ObservationIgnored var onReconnected: (() -> Void)?

    #if canImport(Supabase)
    @ObservationIgnored private var client: SupabaseClient?
    @ObservationIgnored private var messageChannels: [UUID: RealtimeChannelV2] = [:]
    @ObservationIgnored private var messageStatusChannel: RealtimeChannelV2?
    @ObservationIgnored private var conversationChannel: RealtimeChannelV2?
    @ObservationIgnored private var typingChannel: RealtimeChannelV2?

    func configure(client: SupabaseClient) {
        self.client = client
    }
    #endif

    func subscribe(userID: UUID, role: UserRole, conversationIDs: Set<UUID>) {
        let wasConnected = connectionState == .connected
        currentUserID = userID
        currentRole = role
        subscribedConversationIDs = conversationIDs

        #if canImport(Supabase)
        guard let client else {
            AppLogger.networking.warning("RealtimeManager: No Supabase client configured")
            return
        }

        unsubscribeAll(preserveConnectionState: wasConnected)
        if !wasConnected {
            connectionState = .connecting
        }

        subscribeToMessages(client: client, conversationIDs: conversationIDs)
        subscribeToMessageStatusUpdates(client: client, conversationIDs: conversationIDs)
        subscribeToConversations(client: client, userID: userID, role: role)
        subscribeToTyping(client: client, conversationIDs: conversationIDs)
        #endif
    }

    func unsubscribeAll(preserveConnectionState: Bool = false) {
        for task in messageListenerTasks.values { task.cancel() }
        messageListenerTasks.removeAll()
        messageStatusListenerTask?.cancel()
        messageStatusListenerTask = nil
        conversationListenerTask?.cancel()
        typingListenerTask?.cancel()
        conversationListenerTask = nil
        typingListenerTask = nil

        #if canImport(Supabase)
        for channel in messageChannels.values {
            Task { await client?.realtimeV2.removeChannel(channel) }
        }
        messageChannels.removeAll()
        if let messageStatusChannel {
            Task { await client?.realtimeV2.removeChannel(messageStatusChannel) }
        }
        messageStatusChannel = nil
        if let conversationChannel {
            Task { await client?.realtimeV2.removeChannel(conversationChannel) }
        }
        if let typingChannel {
            Task { await client?.realtimeV2.removeChannel(typingChannel) }
        }
        conversationChannel = nil
        typingChannel = nil
        #endif

        if !preserveConnectionState {
            connectionState = .disconnected
        }
        subscribedConversationIDs = []
    }

    func addConversation(_ conversationID: UUID) {
        subscribedConversationIDs.insert(conversationID)

        #if canImport(Supabase)
        if let client {
            subscribeToMessageBroadcast(client: client, conversationID: conversationID)
        }
        #endif
    }

    func sendTypingIndicator(conversationID: UUID, senderRole: String) {
        #if canImport(Supabase)
        guard let typingChannel else { return }

        Task {
            try? await typingChannel.broadcast(
                event: "typing",
                message: [
                    "conversation_id": .string(conversationID.uuidString),
                    "sender_role": .string(senderRole),
                ]
            )
        }
        #endif
    }

    func handleConnectivityChange(isConnected: Bool) {
        if isConnected, connectionState == .disconnected {
            reconnectTask?.cancel()
            reconnectTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }

                if let userID = currentUserID, let role = currentRole {
                    subscribe(userID: userID, role: role, conversationIDs: subscribedConversationIDs)
                    onReconnected?()
                }
            }
        } else if !isConnected {
            connectionState = .disconnected
        }
    }

    #if canImport(Supabase)
    // MARK: - Message broadcast (Database Broadcast via trigger, ~6ms latency)

    private func subscribeToMessages(client: SupabaseClient, conversationIDs: Set<UUID>) {
        for conversationID in conversationIDs {
            subscribeToMessageBroadcast(client: client, conversationID: conversationID)
        }

        connectionState = .connected
        hasEverConnected = true
    }

    private func subscribeToMessageBroadcast(client: SupabaseClient, conversationID: UUID) {
        // Skip if already subscribed
        guard messageListenerTasks[conversationID] == nil else { return }

        let topic = "messages:conv:\(conversationID.uuidString)"
        let channel = client.realtimeV2.channel(topic)

        messageChannels[conversationID] = channel

        messageListenerTasks[conversationID] = Task {
            await channel.subscribe()

            if !hasEverConnected {
                connectionState = .connected
                hasEverConnected = true
            }

            for await message in channel.broadcastStream(event: "new_message") {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: message)
                    let decoder = RealtimePayloadDecoder.makeJSONDecoder()
                    let record = try decoder.decode(MessageRecord.self, from: jsonData)

                    onMessageReceived?(record)
                } catch {
                    AppLogger.networking.error(
                        "Failed to decode broadcast message: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    // MARK: - Message status updates (Postgres Changes UPDATE on messages, for delivery status)

    private func subscribeToMessageStatusUpdates(client: SupabaseClient, conversationIDs: Set<UUID>) {
        let channel = client.realtimeV2.channel("msg-status-\(UUID().uuidString.prefix(8))")

        let postgresChange = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "messages",
            filter: "status=in.(delivered,read)"
        )

        messageStatusChannel = channel

        messageStatusListenerTask = Task {
            await channel.subscribe()

            for await update in postgresChange {
                do {
                    let record = try update.decodeRecord(
                        as: MessageRecord.self,
                        decoder: RealtimePayloadDecoder.makeJSONDecoder()
                    )

                    guard conversationIDs.contains(record.conversationID) else { continue }
                    guard let status = record.status else { continue }

                    onMessageStatusUpdated?(record.id, status)
                } catch {
                    AppLogger.networking.error(
                        "Failed to decode message status update: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    // MARK: - Conversation updates (Postgres Changes, lower volume)

    private func subscribeToConversations(client: SupabaseClient, userID: UUID, role: UserRole) {
        let channel = client.realtimeV2.channel("conversations-\(UUID().uuidString.prefix(8))")

        let postgresChange = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "conversations"
        )

        conversationChannel = channel

        conversationListenerTask = Task {
            await channel.subscribe()

            for await update in postgresChange {
                do {
                    let record = try update.decodeRecord(
                        as: ConversationRecord.self,
                        decoder: RealtimePayloadDecoder.makeJSONDecoder()
                    )

                    let isParticipant = (role == .host && record.hostID == userID) ||
                                        (role == .vendor && record.vendorID == userID)
                    guard isParticipant else { continue }

                    onConversationUpdated?(record)
                } catch {
                    AppLogger.networking.error(
                        "Failed to decode realtime conversation update: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    // MARK: - Typing indicators (Client Broadcast)

    private func subscribeToTyping(client: SupabaseClient, conversationIDs: Set<UUID>) {
        let channel = client.realtimeV2.channel("typing-\(UUID().uuidString.prefix(8))")

        typingChannel = channel

        typingListenerTask = Task {
            await channel.subscribe()

            for await message in channel.broadcastStream(event: "typing") {
                guard let conversationIDString = message["conversation_id"]?.stringValue,
                      let conversationID = UUID(uuidString: conversationIDString),
                      let senderRoleString = message["sender_role"]?.stringValue,
                      let senderRole = ChatMessageSender(rawValue: senderRoleString),
                      conversationIDs.contains(conversationID) else {
                    continue
                }

                if senderRole.userRole == currentRole { continue }

                onTypingReceived?(conversationID, senderRole)

                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    self?.onTypingStopped?(conversationID)
                }
            }
        }
    }
    #endif
}
