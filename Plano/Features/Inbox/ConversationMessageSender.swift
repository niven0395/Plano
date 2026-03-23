import Foundation
import OSLog

@MainActor
final class ConversationMessageSender {
    private let messagingService: any MessagingServiceProtocol

    /// Providers set after init to avoid init-time capture of owning store.
    var offlineSendQueueProvider: () -> OfflineSendQueue? = { nil }
    var networkMonitorProvider: () -> NetworkMonitor? = { nil }
    var currentUserIDProvider: () -> UUID? = { nil }

    /// Callbacks invoked to apply message mutations back to InboxStore.
    var onAppendMessage: ((ChatMessage, UUID, UserRole?) -> Void)?
    var onReplaceOptimistic: ((UUID, UUID, ChatMessage) -> Void)?
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

        // Check network connectivity
        if networkMonitorProvider()?.isConnected == false {
            Task {
                await offlineSendQueueProvider()?.enqueue(
                    clientID: clientID,
                    conversationID: conversationID,
                    body: body,
                    kind: "text",
                    senderRole: role.rawValue
                )
            }
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                print("[InboxStore] sendMessage: userID=\(currentUserIDProvider()?.uuidString ?? "nil"), role=\(role.rawValue), conversationID=\(conversationID)")
                let createdMessage = try await messagingService.sendMessage(
                    conversationID: conversationID,
                    body: body,
                    kind: "text",
                    senderRole: role.rawValue,
                    clientID: clientID
                )

                onReplaceOptimistic?(
                    clientID,
                    conversationID,
                    ChatMessage(
                        id: createdMessage.id,
                        sender: sender(for: role),
                        body: createdMessage.body,
                        sentAt: createdMessage.createdAt,
                        status: .sent,
                        clientID: clientID
                    )
                )
            } catch is CancellationError {
                // Normal task lifecycle
            } catch {
                if networkMonitorProvider()?.isConnected == false {
                    // Network went down during send - queue it
                    onUpdateStatus?(clientID, conversationID, .sending)
                    Task {
                        await offlineSendQueueProvider()?.enqueue(
                            clientID: clientID,
                            conversationID: conversationID,
                            body: body,
                            kind: "text",
                            senderRole: role.rawValue
                        )
                    }
                } else {
                    print("[InboxStore] sendMessage FAILED: \(error)")
                    onUpdateStatus?(clientID, conversationID, .failed)
                    onSetLoadingState?(.failed(error.localizedDescription))
                }
            }
        }
    }

    func sendMessageWithAttachments(
        _ body: String,
        attachments: [PendingAttachment],
        in conversationID: UUID,
        as role: UserRole
    ) {
        guard let userID = currentUserIDProvider() else { return }

        let clientID = UUID()
        let pendingAttachmentModels = attachments.map { pending in
            MessageAttachment(
                storagePath: "",
                fileName: pending.fileName,
                mimeType: pending.mimeType,
                fileSizeBytes: pending.fileSizeBytes
            )
        }

        let optimisticMessage = ChatMessage(
            sender: sender(for: role),
            body: body.isEmpty ? "Sent \(attachments.count) attachment\(attachments.count == 1 ? "" : "s")" : body,
            sentAt: .now,
            kind: .attachment,
            status: .sending,
            clientID: clientID,
            attachments: pendingAttachmentModels
        )

        onAppendMessage?(optimisticMessage, conversationID, role.counterpart)

        Task { [weak self] in
            guard let self else { return }
            do {
                // Upload attachments
                var uploadedPaths: [(path: String, attachment: PendingAttachment)] = []
                for attachment in attachments {
                    let path = try await messagingService.uploadAttachment(
                        data: attachment.data,
                        fileName: attachment.fileName,
                        mimeType: attachment.mimeType,
                        userID: userID
                    )
                    uploadedPaths.append((path, attachment))
                }

                // Send the message
                let messageBody = body.isEmpty ? "Sent \(attachments.count) attachment\(attachments.count == 1 ? "" : "s")" : body
                let createdMessage = try await messagingService.sendMessage(
                    conversationID: conversationID,
                    body: messageBody,
                    kind: "attachment",
                    senderRole: role.rawValue,
                    clientID: clientID
                )

                // Create attachment records
                var finalAttachments: [MessageAttachment] = []
                for (path, pending) in uploadedPaths {
                    let record = try await messagingService.createAttachmentRecord(
                        messageID: createdMessage.id,
                        storagePath: path,
                        fileName: pending.fileName,
                        mimeType: pending.mimeType,
                        fileSizeBytes: pending.fileSizeBytes,
                        width: nil,
                        height: nil
                    )
                    finalAttachments.append(record.toAttachment())
                }

                onReplaceOptimistic?(
                    clientID,
                    conversationID,
                    ChatMessage(
                        id: createdMessage.id,
                        sender: sender(for: role),
                        body: createdMessage.body,
                        sentAt: createdMessage.createdAt,
                        kind: .attachment,
                        status: .sent,
                        clientID: clientID,
                        attachments: finalAttachments
                    )
                )
            } catch is CancellationError {
                // Normal task lifecycle
            } catch {
                onUpdateStatus?(clientID, conversationID, .failed)
                onSetLoadingState?(.failed(error.localizedDescription))
            }
        }
    }

    func retryFailedMessage(clientID: UUID, body: String, in conversationID: UUID, as role: UserRole) {
        // Reuse the original clientID to preserve position and avoid duplicates
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

                onReplaceOptimistic?(
                    clientID,
                    conversationID,
                    ChatMessage(
                        id: createdMessage.id,
                        sender: sender(for: role),
                        body: createdMessage.body,
                        sentAt: createdMessage.createdAt,
                        status: .sent,
                        clientID: clientID
                    )
                )
            } catch is CancellationError {
                // Normal task lifecycle
            } catch {
                if networkMonitorProvider()?.isConnected == false {
                    onUpdateStatus?(clientID, conversationID, .sending)
                    Task {
                        await offlineSendQueueProvider()?.enqueue(
                            clientID: clientID,
                            conversationID: conversationID,
                            body: body,
                            kind: "text",
                            senderRole: role.rawValue
                        )
                    }
                } else {
                    onUpdateStatus?(clientID, conversationID, .failed)
                    onSetLoadingState?(.failed(error.localizedDescription))
                }
            }
        }
    }

    private func sender(for role: UserRole) -> ChatMessageSender {
        switch role {
        case .host: .host
        case .vendor: .vendor
        }
    }
}
