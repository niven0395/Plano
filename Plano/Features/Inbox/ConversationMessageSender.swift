import Foundation
import OSLog

@MainActor
final class ConversationMessageSender {
    private let messagingService: any MessagingServiceProtocol
    private let attachmentStagingDirectory = URL.applicationSupportDirectory
        .appending(path: "OfflineMessageAttachments", directoryHint: .isDirectory)

    /// Providers set after init to avoid init-time capture of owning store.
    var offlineSendQueueProvider: () -> OfflineSendQueue? = { nil }
    var networkMonitorProvider: () -> NetworkMonitor? = { nil }
    var currentUserIDProvider: () -> UUID? = { nil }

    /// Callbacks invoked to apply message mutations back to InboxStore.
    var onAppendMessage: ((ChatMessage, UUID, UserRole?) -> Void)?
    var onPersistedMessage: ((UUID, UUID, MessageSendResult) -> Void)?
    var onUpdateStatus: ((UUID, UUID, MessageDeliveryStatus) -> Void)?
    var onSetLoadingState: ((LoadingState) -> Void)?

    init(messagingService: any MessagingServiceProtocol) {
        self.messagingService = messagingService
    }

    func sendMessage(_ body: String, in conversationID: UUID, as role: UserRole) {
        let clientID = UUID()
        let optimisticMessage = ChatMessage(
            sender: sender(for: role),
            body: body,
            sentAt: .now,
            status: .sending,
            clientID: clientID
        )

        onAppendMessage?(optimisticMessage, conversationID, role.counterpart)

        guard networkMonitorProvider()?.isConnected != false else {
            queueTextMessage(
                clientID: clientID,
                conversationID: conversationID,
                body: body,
                role: role
            )
            return
        }

        Task { [weak self] in
            guard let self else { return }

            do {
                let createdMessage = try await messagingService.sendMessage(
                    conversationID: conversationID,
                    body: body,
                    kind: "text",
                    senderRole: role.rawValue,
                    clientID: clientID
                )

                onPersistedMessage?(
                    clientID,
                    conversationID,
                    MessageSendResult(message: createdMessage)
                )
            } catch is CancellationError {
                // Normal task lifecycle
            } catch {
                guard networkMonitorProvider()?.isConnected == false else {
                    AppLogger.networking.error("Failed to send text message: \(error.localizedDescription, privacy: .public)")
                    onUpdateStatus?(clientID, conversationID, .failed)
                    onSetLoadingState?(.failed(error.localizedDescription))
                    return
                }

                onUpdateStatus?(clientID, conversationID, .sending)
                queueTextMessage(
                    clientID: clientID,
                    conversationID: conversationID,
                    body: body,
                    role: role
                )
            }
        }
    }

    func sendMessageWithAttachments(
        _ body: String,
        attachments: [PendingAttachment],
        in conversationID: UUID,
        as role: UserRole
    ) {
        guard let userID = currentUserIDProvider() else {
            onSetLoadingState?(.failed("No active user is available for this attachment upload."))
            return
        }

        let clientID = UUID()
        let optimisticAttachments = attachments.map { attachment in
            MessageAttachment(
                storagePath: "",
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                fileSizeBytes: attachment.fileSizeBytes
            )
        }

        let optimisticMessage = ChatMessage(
            sender: sender(for: role),
            body: messageBody(body, attachmentCount: attachments.count),
            sentAt: .now,
            kind: .attachment,
            status: .sending,
            clientID: clientID,
            attachments: optimisticAttachments
        )

        onAppendMessage?(optimisticMessage, conversationID, role.counterpart)

        guard networkMonitorProvider()?.isConnected != false else {
            queueAttachmentMessage(
                clientID: clientID,
                conversationID: conversationID,
                body: messageBody(body, attachmentCount: attachments.count),
                role: role,
                attachments: attachments
            )
            return
        }

        Task { [weak self] in
            guard let self else { return }

            do {
                let uploads = try await uploadAttachments(attachments, userID: userID)
                let result = try await messagingService.sendMessageWithAttachments(
                    conversationID: conversationID,
                    body: messageBody(body, attachmentCount: attachments.count),
                    kind: "attachment",
                    clientID: clientID,
                    attachments: uploads
                )

                onPersistedMessage?(clientID, conversationID, result)
            } catch is CancellationError {
                // Normal task lifecycle
            } catch {
                guard networkMonitorProvider()?.isConnected == false else {
                    AppLogger.networking.error("Failed to send attachment message: \(error.localizedDescription, privacy: .public)")
                    onUpdateStatus?(clientID, conversationID, .failed)
                    onSetLoadingState?(.failed(error.localizedDescription))
                    return
                }

                onUpdateStatus?(clientID, conversationID, .sending)
                queueAttachmentMessage(
                    clientID: clientID,
                    conversationID: conversationID,
                    body: messageBody(body, attachmentCount: attachments.count),
                    role: role,
                    attachments: attachments
                )
            }
        }
    }

    func retryFailedMessage(clientID: UUID, body: String, in conversationID: UUID, as role: UserRole) {
        onUpdateStatus?(clientID, conversationID, .sending)

        Task { [weak self] in
            guard let self else { return }

            do {
                let createdMessage = try await messagingService.sendMessage(
                    conversationID: conversationID,
                    body: body,
                    kind: "text",
                    senderRole: role.rawValue,
                    clientID: clientID
                )

                onPersistedMessage?(
                    clientID,
                    conversationID,
                    MessageSendResult(message: createdMessage)
                )
            } catch is CancellationError {
                // Normal task lifecycle
            } catch {
                guard networkMonitorProvider()?.isConnected == false else {
                    onUpdateStatus?(clientID, conversationID, .failed)
                    onSetLoadingState?(.failed(error.localizedDescription))
                    return
                }

                onUpdateStatus?(clientID, conversationID, .sending)
                queueTextMessage(
                    clientID: clientID,
                    conversationID: conversationID,
                    body: body,
                    role: role
                )
            }
        }
    }

    private func queueTextMessage(
        clientID: UUID,
        conversationID: UUID,
        body: String,
        role: UserRole
    ) {
        guard let ownerUserID = currentUserIDProvider() else {
            onUpdateStatus?(clientID, conversationID, .failed)
            onSetLoadingState?(.failed("No active user is available for offline sending."))
            return
        }

        Task {
            await offlineSendQueueProvider()?.enqueue(
                ownerUserID: ownerUserID,
                clientID: clientID,
                conversationID: conversationID,
                body: body,
                kind: "text",
                senderRole: role.rawValue
            )
        }
    }

    private func queueAttachmentMessage(
        clientID: UUID,
        conversationID: UUID,
        body: String,
        role: UserRole,
        attachments: [PendingAttachment]
    ) {
        guard let ownerUserID = currentUserIDProvider() else {
            onUpdateStatus?(clientID, conversationID, .failed)
            onSetLoadingState?(.failed("No active user is available for offline attachment sending."))
            return
        }

        do {
            let stagedAttachments = try stageAttachments(attachments)
            Task {
                await offlineSendQueueProvider()?.enqueue(
                    ownerUserID: ownerUserID,
                    clientID: clientID,
                    conversationID: conversationID,
                    body: body,
                    kind: "attachment",
                    senderRole: role.rawValue,
                    attachments: stagedAttachments
                )
            }
        } catch {
            AppLogger.networking.error("Failed to stage attachments for offline queue: \(error.localizedDescription, privacy: .public)")
            onUpdateStatus?(clientID, conversationID, .failed)
            onSetLoadingState?(.failed(error.localizedDescription))
        }
    }

    private func uploadAttachments(
        _ attachments: [PendingAttachment],
        userID: UUID
    ) async throws -> [MessageAttachmentUpload] {
        var uploads: [MessageAttachmentUpload] = []
        uploads.reserveCapacity(attachments.count)

        for attachment in attachments {
            let path = try await messagingService.uploadAttachment(
                data: attachment.data,
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                userID: userID
            )

            uploads.append(
                MessageAttachmentUpload(
                    storagePath: path,
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

    private func stageAttachments(
        _ attachments: [PendingAttachment]
    ) throws -> [OfflineSendQueue.PendingAttachmentInfo] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: attachmentStagingDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return try attachments.map { attachment in
            let sanitizedName = URL(fileURLWithPath: attachment.fileName).lastPathComponent
            let fileURL = attachmentStagingDirectory.appending(path: "\(UUID().uuidString)_\(sanitizedName)")
            try attachment.data.write(to: fileURL, options: .atomic)
            return OfflineSendQueue.PendingAttachmentInfo(
                localFilePath: fileURL.path,
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                fileSizeBytes: attachment.fileSizeBytes
            )
        }
    }

    private func messageBody(_ body: String, attachmentCount: Int) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }
        return "Sent \(attachmentCount) attachment\(attachmentCount == 1 ? "" : "s")"
    }

    private func sender(for role: UserRole) -> ChatMessageSender {
        switch role {
        case .host:
            .host
        case .vendor:
            .vendor
        }
    }
}
