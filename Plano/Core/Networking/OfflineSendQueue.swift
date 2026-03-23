import Foundation
import OSLog

actor OfflineSendQueue {
    struct PendingAttachmentInfo: Codable {
        let localFilePath: String
        let fileName: String
        let mimeType: String
        let fileSizeBytes: Int64
    }

    struct PendingMessage: Codable, Identifiable {
        let id: UUID
        let clientID: UUID
        let conversationID: UUID
        let body: String
        let kind: String
        let senderRole: String
        let createdAt: Date
        var retryCount: Int
        var lastAttemptAt: Date?
        /// Optional attachment info for queued attachment messages.
        var attachment: PendingAttachmentInfo?

        var nextRetryDelay: TimeInterval {
            let base: TimeInterval = 1
            let delay = base * pow(2, Double(retryCount))
            return min(delay, 60)
        }
    }

    private var queue: [PendingMessage] = []
    private let fileURL: URL
    private var isDraining = false
    private var drainTask: Task<Void, Never>?

    private let messagingService: any MessagingServiceProtocol
    private let onMessageSent: @Sendable (UUID, UUID, MessageRecord) async -> Void
    private let onMessageFailed: @Sendable (UUID, UUID) async -> Void

    init(
        messagingService: any MessagingServiceProtocol,
        onMessageSent: @escaping @Sendable (UUID, UUID, MessageRecord) async -> Void,
        onMessageFailed: @escaping @Sendable (UUID, UUID) async -> Void
    ) {
        self.messagingService = messagingService
        self.onMessageSent = onMessageSent
        self.onMessageFailed = onMessageFailed
        self.fileURL = URL.documentsDirectory.appending(path: "offline-send-queue.json")
        loadFromDisk()
    }

    var pendingCount: Int { queue.count }

    var pendingClientIDs: Set<UUID> {
        Set(queue.map(\.clientID))
    }

    func enqueue(
        clientID: UUID,
        conversationID: UUID,
        body: String,
        kind: String,
        senderRole: String,
        attachment: PendingAttachmentInfo? = nil
    ) {
        let message = PendingMessage(
            id: UUID(),
            clientID: clientID,
            conversationID: conversationID,
            body: body,
            kind: kind,
            senderRole: senderRole,
            createdAt: .now,
            retryCount: 0,
            attachment: attachment
        )

        queue.append(message)
        saveToDisk()

        AppLogger.networking.notice("Queued offline message \(clientID.uuidString, privacy: .public)\(attachment != nil ? " (with attachment)" : "")")
    }

    func drain() {
        guard !isDraining, !queue.isEmpty else { return }

        drainTask?.cancel()
        drainTask = Task { [weak self] in
            guard let self else { return }
            await performDrain()
        }
    }

    func cancelDrain() {
        drainTask?.cancel()
        drainTask = nil
        isDraining = false
    }

    func removeMessage(clientID: UUID) {
        queue.removeAll { $0.clientID == clientID }
        saveToDisk()
    }

    private func performDrain() {
        isDraining = true

        Task {
            while !queue.isEmpty {
                guard !Task.isCancelled else { break }

                let message = queue[0]

                // Wait for retry delay if needed
                if message.retryCount > 0 {
                    let delay = message.nextRetryDelay
                    do {
                        try await Task.sleep(for: .seconds(delay))
                    } catch {
                        break
                    }
                }

                do {
                    let record: MessageRecord

                    if let attachmentInfo = message.attachment {
                        // Upload attachment first, then send message with attachment
                        let localURL = URL(fileURLWithPath: attachmentInfo.localFilePath)
                        let data = try Data(contentsOf: localURL)
                        let senderID = UUID() // Placeholder — will be resolved by server
                        let storagePath = try await messagingService.uploadAttachment(
                            data: data,
                            fileName: attachmentInfo.fileName,
                            mimeType: attachmentInfo.mimeType,
                            userID: senderID
                        )

                        record = try await messagingService.sendMessageWithAttachment(
                            conversationID: message.conversationID,
                            body: message.body,
                            kind: message.kind,
                            clientID: message.clientID,
                            storagePath: storagePath,
                            fileName: attachmentInfo.fileName,
                            mimeType: attachmentInfo.mimeType,
                            fileSizeBytes: attachmentInfo.fileSizeBytes,
                            width: nil,
                            height: nil
                        )
                    } else {
                        record = try await messagingService.sendMessage(
                            conversationID: message.conversationID,
                            body: message.body,
                            kind: message.kind,
                            senderRole: message.senderRole,
                            clientID: message.clientID
                        )
                    }

                    // Success - remove from queue
                    queue.removeAll { $0.id == message.id }
                    saveToDisk()

                    await onMessageSent(message.conversationID, message.clientID, record)

                    AppLogger.networking.notice(
                        "Offline message sent: \(message.clientID.uuidString, privacy: .public)"
                    )
                } catch {
                    if isNonRetryable(error) {
                        // Permanent failure - remove and notify
                        queue.removeAll { $0.id == message.id }
                        saveToDisk()
                        await onMessageFailed(message.conversationID, message.clientID)

                        AppLogger.networking.error(
                            "Offline message permanently failed: \(error.localizedDescription, privacy: .public)"
                        )
                    } else {
                        // Transient failure - increment retry count
                        if let index = queue.firstIndex(where: { $0.id == message.id }) {
                            queue[index].retryCount += 1
                            queue[index].lastAttemptAt = .now

                            if queue[index].retryCount >= 10 {
                                queue.remove(at: index)
                                await onMessageFailed(message.conversationID, message.clientID)
                                AppLogger.networking.error(
                                    "Offline message exhausted retries: \(message.clientID.uuidString, privacy: .public)"
                                )
                            }
                        }
                        saveToDisk()
                    }
                }
            }

            isDraining = false
        }
    }

    private func isNonRetryable(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized, .notConfigured, .notSupported:
                return true
            case .offline, .invalidResponse, .unknown:
                return false
            }
        }
        return false
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            queue = try JSONDecoder().decode([PendingMessage].self, from: data)
            AppLogger.networking.notice("Loaded \(self.queue.count, privacy: .public) queued messages from disk")
        } catch {
            AppLogger.networking.error("Failed to load offline queue: \(error.localizedDescription, privacy: .public)")
            queue = []
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            AppLogger.networking.error("Failed to save offline queue: \(error.localizedDescription, privacy: .public)")
        }
    }
}
