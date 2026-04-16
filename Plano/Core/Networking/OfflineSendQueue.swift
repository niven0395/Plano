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
        let ownerUserID: UUID
        let clientID: UUID
        let conversationID: UUID
        let body: String
        let kind: String
        let senderRole: String
        let createdAt: Date
        var retryCount: Int
        var lastAttemptAt: Date?
        var attachments: [PendingAttachmentInfo]

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
    private var activeDrainUserID: UUID?

    private let messagingService: any MessagingServiceProtocol
    private let onMessageSent: @Sendable (UUID, UUID, MessageSendResult) async -> Void
    private let onMessageFailed: @Sendable (UUID, UUID) async -> Void

    init(
        messagingService: any MessagingServiceProtocol,
        onMessageSent: @escaping @Sendable (UUID, UUID, MessageSendResult) async -> Void,
        onMessageFailed: @escaping @Sendable (UUID, UUID) async -> Void
    ) {
        self.messagingService = messagingService
        self.onMessageSent = onMessageSent
        self.onMessageFailed = onMessageFailed
        self.fileURL = URL.documentsDirectory.appending(path: "offline-send-queue.json")
        loadFromDisk()
    }

    func pendingCount(for ownerUserID: UUID?) -> Int {
        guard let ownerUserID else { return 0 }
        return queue.filter { $0.ownerUserID == ownerUserID }.count
    }

    func pendingClientIDs(for ownerUserID: UUID?) -> Set<UUID> {
        guard let ownerUserID else { return [] }
        return Set(queue.lazy.filter { $0.ownerUserID == ownerUserID }.map(\.clientID))
    }

    func enqueue(
        ownerUserID: UUID,
        clientID: UUID,
        conversationID: UUID,
        body: String,
        kind: String,
        senderRole: String,
        attachments: [PendingAttachmentInfo] = []
    ) {
        let message = PendingMessage(
            id: UUID(),
            ownerUserID: ownerUserID,
            clientID: clientID,
            conversationID: conversationID,
            body: body,
            kind: kind,
            senderRole: senderRole,
            createdAt: .now,
            retryCount: 0,
            attachments: attachments
        )

        queue.append(message)
        saveToDisk()

        AppLogger.networking.notice(
            "Queued offline message \(clientID.uuidString, privacy: .public)\(attachments.isEmpty ? "" : " (with attachments)")"
        )
    }

    func drain(for ownerUserID: UUID?) {
        guard let ownerUserID else { return }
        guard queue.contains(where: { $0.ownerUserID == ownerUserID }) else { return }

        if isDraining, activeDrainUserID == ownerUserID {
            return
        }

        drainTask?.cancel()
        activeDrainUserID = ownerUserID
        drainTask = Task { [weak self] in
            guard let self else { return }
            await performDrain(for: ownerUserID)
        }
    }

    func cancelDrain() {
        drainTask?.cancel()
        drainTask = nil
        isDraining = false
        activeDrainUserID = nil
    }

    func removeMessage(clientID: UUID, ownerUserID: UUID? = nil) {
        queue.removeAll {
            $0.clientID == clientID &&
            (ownerUserID == nil || $0.ownerUserID == ownerUserID)
        }
        saveToDisk()
    }

    private func performDrain(for ownerUserID: UUID) async {
        isDraining = true
        defer {
            if activeDrainUserID == ownerUserID {
                isDraining = false
                activeDrainUserID = nil
            }
        }

        while let index = queue.firstIndex(where: { $0.ownerUserID == ownerUserID }) {
            guard !Task.isCancelled else { break }

            let message = queue[index]

            if message.retryCount > 0 {
                let delay = message.nextRetryDelay
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    break
                }
            }

            do {
                let result: MessageSendResult

                if message.attachments.isEmpty {
                    let record = try await messagingService.sendMessage(
                        conversationID: message.conversationID,
                        body: message.body,
                        kind: message.kind,
                        senderRole: message.senderRole,
                        clientID: message.clientID
                    )
                    result = MessageSendResult(message: record)
                } else {
                    let uploads = try await uploadAttachments(for: message)
                    result = try await messagingService.sendMessageWithAttachments(
                        conversationID: message.conversationID,
                        body: message.body,
                        kind: message.kind,
                        clientID: message.clientID,
                        attachments: uploads
                    )
                }

                queue.removeAll { $0.id == message.id }
                saveToDisk()
                cleanupAttachments(message.attachments)

                await onMessageSent(message.conversationID, message.clientID, result)

                AppLogger.networking.notice(
                    "Offline message sent: \(message.clientID.uuidString, privacy: .public)"
                )
            } catch {
                if isNonRetryable(error) {
                    queue.removeAll { $0.id == message.id }
                    saveToDisk()
                    cleanupAttachments(message.attachments)
                    await onMessageFailed(message.conversationID, message.clientID)

                    AppLogger.networking.error(
                        "Offline message permanently failed: \(error.localizedDescription, privacy: .public)"
                    )
                } else {
                    if let retryIndex = queue.firstIndex(where: { $0.id == message.id }) {
                        queue[retryIndex].retryCount += 1
                        queue[retryIndex].lastAttemptAt = .now

                        if queue[retryIndex].retryCount >= 10 {
                            let exhaustedMessage = queue.remove(at: retryIndex)
                            cleanupAttachments(exhaustedMessage.attachments)
                            await onMessageFailed(exhaustedMessage.conversationID, exhaustedMessage.clientID)
                            AppLogger.networking.error(
                                "Offline message exhausted retries: \(exhaustedMessage.clientID.uuidString, privacy: .public)"
                            )
                        }
                    }

                    saveToDisk()
                }
            }
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

    private func uploadAttachments(for message: PendingMessage) async throws -> [MessageAttachmentUpload] {
        var uploads: [MessageAttachmentUpload] = []
        uploads.reserveCapacity(message.attachments.count)

        for attachment in message.attachments {
            let localURL = URL(fileURLWithPath: attachment.localFilePath)
            let data = try Data(contentsOf: localURL)
            let storagePath = try await messagingService.uploadAttachment(
                data: data,
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                userID: message.ownerUserID
            )

            uploads.append(
                MessageAttachmentUpload(
                    storagePath: storagePath,
                    fileName: attachment.fileName,
                    mimeType: attachment.mimeType,
                    fileSizeBytes: attachment.fileSizeBytes,
                    width: nil,
                    height: nil
                )
            )
        }

        return uploads
    }

    private func cleanupAttachments(_ attachments: [PendingAttachmentInfo]) {
        let fileManager = FileManager.default
        for attachment in attachments {
            try? fileManager.removeItem(at: URL(fileURLWithPath: attachment.localFilePath))
        }
    }
}
