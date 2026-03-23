import Foundation
import OSLog

/// Describes a mutation to apply to InboxStore's conversations array and related state.
struct BookingMutation {
    var conversationUpdate: ((inout ConversationThread) -> Void)?
    var dateConflictsUpdate: (UUID, [DateConflict]?)?
    var archiveAction: (UUID, UserRole)?
    var loadingState: LoadingState?
}

@MainActor
final class ConversationBookingCoordinator {
    private let bookingService: any BookingServiceProtocol
    private let sessionStore: SessionStore

    /// Mutable state owned by InboxStore, forwarded here for reads.
    var confirmingPaymentIDs: Set<UUID> = []
    var confirmPaymentError: String?
    var bookingActionError: String?

    init(
        bookingService: any BookingServiceProtocol,
        sessionStore: SessionStore
    ) {
        self.bookingService = bookingService
        self.sessionStore = sessionStore
    }

    // MARK: - Accept

    func acceptBooking(
        in conversationID: UUID,
        conversationIndex: Int?,
        mutateConversations: ((inout [ConversationThread]) -> Void) -> Void,
        reloadConversations: () async -> Void,
        setLoadingState: (LoadingState) -> Void
    ) async {
        guard let index = conversationIndex else {
            do {
                _ = try await bookingService.acceptBooking(conversationID: conversationID)
                await reloadConversations()
            } catch {
                setLoadingState(.failed(error.localizedDescription))
            }
            return
        }

        var previous: ConversationThread?
        mutateConversations { conversations in
            previous = conversations[index]
            conversations[index].stage = .accepted
            conversations[index].messages.append(ChatMessage(
                sender: .system,
                body: "Booking accepted by vendor.",
                sentAt: .now,
                kind: .system
            ))
        }

        do {
            _ = try await bookingService.acceptBooking(conversationID: conversationID)
        } catch {
            if let previous {
                mutateConversations { conversations in
                    conversations[index] = previous
                }
            }
            bookingActionError = error.localizedDescription
        }
    }

    // MARK: - Decline

    func declineBooking(
        in conversationID: UUID,
        reason: String?,
        conversationIndex: Int?,
        mutateConversations: ((inout [ConversationThread]) -> Void) -> Void,
        reloadConversations: () async -> Void,
        setLoadingState: (LoadingState) -> Void
    ) async {
        guard let index = conversationIndex else {
            do {
                _ = try await bookingService.declineBooking(conversationID: conversationID, reason: reason)
                await reloadConversations()
            } catch {
                setLoadingState(.failed(error.localizedDescription))
            }
            return
        }

        var previous: ConversationThread?
        let message = reason.flatMap { $0.isEmpty ? nil : $0 }
            .map { "The vendor declined this request. \($0)" }
            ?? "The vendor declined this request."

        mutateConversations { conversations in
            previous = conversations[index]
            conversations[index].stage = .declined
            conversations[index].messages.append(ChatMessage(
                sender: .system,
                body: message,
                sentAt: .now,
                kind: .system
            ))
        }

        do {
            _ = try await bookingService.declineBooking(conversationID: conversationID, reason: reason)
        } catch {
            if let previous {
                mutateConversations { conversations in
                    conversations[index] = previous
                }
            }
            bookingActionError = error.localizedDescription
        }
    }

    // MARK: - Request payment

    func requestPayment(
        in conversationID: UUID,
        amountCents: Int,
        note: String?,
        paymentType: PaymentType,
        vendorEmail: String?,
        conversationIndex: Int?,
        mutateConversations: ((inout [ConversationThread]) -> Void) -> Void,
        reloadConversations: () async -> Void,
        setLoadingState: (LoadingState) -> Void
    ) async {
        guard let index = conversationIndex else {
            do {
                _ = try await bookingService.requestPayment(
                    conversationID: conversationID,
                    amountCents: amountCents,
                    note: VendorPaymentRequestComposer.normalized(note),
                    paymentType: paymentType.rawValue
                )
                await reloadConversations()
            } catch {
                setLoadingState(.failed(error.localizedDescription))
            }
            return
        }

        var previous: ConversationThread?
        let normalizedNote = VendorPaymentRequestComposer.normalized(note)

        mutateConversations { conversations in
            previous = conversations[index]
            conversations[index].stage = .paymentRequested
            conversations[index].paymentRequest = PaymentRequest(
                amountCents: amountCents,
                note: normalizedNote ?? "",
                requestedAt: .now,
                paymentType: paymentType,
                vendorEmail: vendorEmail
            )
            conversations[index].messages.append(ChatMessage(
                sender: .system,
                body: VendorPaymentRequestComposer.messageBody(amountCents: amountCents, note: normalizedNote, paymentType: paymentType, vendorEmail: vendorEmail),
                sentAt: .now,
                kind: .paymentRequest
            ))
        }

        do {
            _ = try await bookingService.requestPayment(
                conversationID: conversationID,
                amountCents: amountCents,
                note: normalizedNote,
                paymentType: paymentType.rawValue
            )
        } catch {
            if let previous {
                mutateConversations { conversations in
                    conversations[index] = previous
                }
            }
            bookingActionError = error.localizedDescription
        }
    }

    // MARK: - Confirm payment

    func confirmPayment(
        in conversationID: UUID,
        mutateConversations: ((inout [ConversationThread]) -> Void) -> Void,
        findConversationIndex: (UUID) -> Int?,
        reloadConversations: () async -> Void
    ) async {
        guard !confirmingPaymentIDs.contains(conversationID) else { return }
        confirmingPaymentIDs.insert(conversationID)
        confirmPaymentError = nil

        do {
            _ = try await bookingService.confirmPayment(conversationID: conversationID)

            if let index = findConversationIndex(conversationID) {
                mutateConversations { conversations in
                    conversations[index].stage = .paid
                    conversations[index].paymentRequest?.status = .paid
                    conversations[index].lastActivityAt = .now
                    conversations[index].messages.append(ChatMessage(
                        sender: .system,
                        body: "Payment confirmed. Booking is now paid.",
                        sentAt: .now,
                        kind: .system
                    ))
                }
            } else {
                await reloadConversations()
            }
        } catch {
            confirmPaymentError = error.localizedDescription
            AppLogger.booking.error("Failed to confirm payment for \(conversationID): \(error.localizedDescription, privacy: .public)")
        }

        confirmingPaymentIDs.remove(conversationID)
    }

    // MARK: - Vendor confirm payment

    func vendorConfirmPayment(
        in conversationID: UUID,
        mutateConversations: ((inout [ConversationThread]) -> Void) -> Void,
        findConversationIndex: (UUID) -> Int?,
        reloadConversations: () async -> Void
    ) async {
        guard !confirmingPaymentIDs.contains(conversationID) else { return }
        confirmingPaymentIDs.insert(conversationID)
        confirmPaymentError = nil

        do {
            _ = try await bookingService.vendorConfirmPayment(conversationID: conversationID)

            if let index = findConversationIndex(conversationID) {
                mutateConversations { conversations in
                    conversations[index].stage = .paid
                    conversations[index].paymentRequest?.status = .paid
                    conversations[index].lastActivityAt = .now
                    conversations[index].messages.append(ChatMessage(
                        sender: .system,
                        body: "Vendor confirmed payment received. Booking is now paid.",
                        sentAt: .now,
                        kind: .system
                    ))
                }
            } else {
                await reloadConversations()
            }
        } catch {
            confirmPaymentError = error.localizedDescription
            AppLogger.booking.error("Failed to vendor-confirm payment for \(conversationID): \(error.localizedDescription, privacy: .public)")
        }

        confirmingPaymentIDs.remove(conversationID)
    }

    // MARK: - Cancel booking

    func cancelBooking(
        in conversationID: UUID,
        reason: String?,
        snapshot: ConversationThread,
        currentRole: UserRole,
        previousConflicts: [DateConflict]?
    ) -> (
        optimisticMutation: (inout ConversationThread) -> Void,
        serverTask: @Sendable () async throws -> BookingTransitionResult
    ) {
        let messageBody = reason.map { "The booking was cancelled. \($0)" } ?? "The booking was cancelled."

        let mutation: (inout ConversationThread) -> Void = { [currentRole] thread in
            thread.stage = .cancelled
            thread.messages.append(
                ChatMessage(
                    sender: .system,
                    body: messageBody,
                    sentAt: .now
                )
            )
            thread.lastActivityAt = .now

            switch currentRole {
            case .host:
                thread.vendorUnreadCount += 1
            case .vendor:
                thread.hostUnreadCount += 1
            }
        }

        let serverTask: @Sendable () async throws -> BookingTransitionResult = { [bookingService] in
            try await bookingService.cancelBooking(conversationID: conversationID, reason: reason)
        }

        return (mutation, serverTask)
    }

    // MARK: - Respond to cancellation request

    func respondToCancellationRequest(
        in conversationID: UUID,
        approved: Bool,
        reason: String?,
        conversationIndex: Int?,
        mutateConversations: ((inout [ConversationThread]) -> Void) -> Void,
        reloadConversations: () async -> Void,
        setLoadingState: (LoadingState) -> Void
    ) async {
        guard let index = conversationIndex else {
            do {
                _ = try await bookingService.respondToCancellationRequest(conversationID: conversationID, approved: approved, reason: reason)
                await reloadConversations()
            } catch {
                setLoadingState(.failed(error.localizedDescription))
            }
            return
        }

        if approved {
            var previous: ConversationThread?
            mutateConversations { conversations in
                previous = conversations[index]
                conversations[index].stage = .cancelled
                conversations[index].messages.append(ChatMessage(
                    sender: .system,
                    body: "The vendor approved the cancellation request.",
                    sentAt: .now,
                    kind: .system
                ))
            }

            do {
                _ = try await bookingService.respondToCancellationRequest(conversationID: conversationID, approved: true, reason: nil)
            } catch {
                if let previous {
                    mutateConversations { conversations in
                        conversations[index] = previous
                    }
                }
                bookingActionError = error.localizedDescription
            }
        } else {
            do {
                _ = try await bookingService.respondToCancellationRequest(conversationID: conversationID, approved: false, reason: reason)
                await reloadConversations()
            } catch {
                bookingActionError = error.localizedDescription
            }
        }
    }

    // MARK: - Force cancel booking

    func forceCancelBooking(
        in conversationID: UUID,
        reason: String?,
        snapshot: ConversationThread,
        currentRole: UserRole
    ) -> (
        optimisticMutation: (inout ConversationThread) -> Void,
        serverTask: @Sendable () async throws -> BookingTransitionResult
    ) {
        let messageBody = "The booking was cancelled. The cancellation was processed despite the earlier decline."

        let mutation: (inout ConversationThread) -> Void = { [currentRole] thread in
            thread.stage = .cancelled
            thread.messages.append(
                ChatMessage(
                    sender: .system,
                    body: messageBody,
                    sentAt: .now
                )
            )
            thread.lastActivityAt = .now
            thread.cancellationRequestDeadline = nil
            thread.cancellationRequestedByRole = nil
            thread.cancellationDeclinedAt = nil

            switch currentRole {
            case .host:
                thread.vendorUnreadCount += 1
            case .vendor:
                thread.hostUnreadCount += 1
            }
        }

        let serverTask: @Sendable () async throws -> BookingTransitionResult = { [bookingService] in
            try await bookingService.forceCancelBooking(conversationID: conversationID, reason: reason)
        }

        return (mutation, serverTask)
    }

    // MARK: - Submit booking request

    func submitBookingRequest(
        in conversationID: UUID,
        eventDate: Date,
        note: String,
        snapshot: ConversationThread
    ) -> (
        optimisticMutation: (inout ConversationThread) -> Void,
        serverTask: @Sendable () async throws -> Void
    )? {
        let blockingStages: Set<BookingStage> = [.requested, .accepted, .paymentRequested, .paid]
        guard !blockingStages.contains(snapshot.stage) else { return nil }

        let optimisticMessage = ChatMessage(
            sender: .host,
            body: "Booking request sent.",
            sentAt: .now,
            kind: .system
        )

        let mutation: (inout ConversationThread) -> Void = { thread in
            thread.bookingEventDate = eventDate
            thread.stage = .requested
            thread.messages.append(optimisticMessage)
            thread.lastActivityAt = optimisticMessage.sentAt
            thread.vendorUnreadCount += 1
        }

        let serverTask: @Sendable () async throws -> Void = { [bookingService] in
            _ = try await bookingService.submitBookingRequest(
                conversationID: conversationID,
                eventDate: eventDate,
                note: note
            )
        }

        return (mutation, serverTask)
    }
}
