import Foundation
import OSLog

// MARK: - Start conversation, booking state transitions, date conflicts

extension InboxStore {

    func startConversation(with vendor: VendorProfile, event: PartyEvent?) async throws -> UUID {
        guard let hostUserID = sessionStore.currentUserID else {
            throw APIError.unauthorized
        }

        guard vendor.id != hostUserID else {
            throw ConversationError.selfMessaging
        }

        if let existingID = existingConversationID(vendorID: vendor.id, eventID: event?.id) {
            return existingID
        }

        let record = try await bookingService.createConversation(
            vendorID: vendor.id,
            hostID: hostUserID,
            eventID: event?.id
        )

        let thread = ConversationThread(
            id: record.id,
            eventID: record.eventID,
            eventDate: event?.date,
            vendorID: record.vendorID,
            hostUserID: record.hostID,
            hostName: record.hostDisplayName,
            vendorName: record.vendorDisplayName,
            vendorCategory: VendorCategory(rawValue: record.vendorCategory) ?? vendor.category,
            eventTitle: record.eventTitle ?? "Direct inquiry",
            eventDateLabel: record.eventDateLabel ?? "Date pending",
            eventContextLine: record.eventContextLine ?? "Guest count pending",
            stage: BookingStage.fromDatabaseValue(record.stage),
            messages: [
                ChatMessage(
                    sender: .system,
                    body: event == nil
                        ? "Conversation started from a direct vendor inquiry."
                        : "Conversation started with the event brief attached.",
                    sentAt: record.createdAt ?? .now
                ),
            ],
            lastActivityAt: record.lastActivityAt,
            hostUnreadCount: 0,
            vendorUnreadCount: 0
        )

        vendorProfilesByID[vendor.id] = vendor
        conversations.insert(thread, at: 0)
        conversations.sort { $0.lastActivityAt > $1.lastActivityAt }

        analyticsService.track(AnalyticsEvent(
            eventType: .conversationStarted,
            vendorID: vendor.id,
            eventID: event?.id
        ))

        return thread.id
    }

    // MARK: - Booking actions (delegates to ConversationBookingCoordinator)

    func submitBookingRequest(in conversationID: UUID, eventDate: Date, note: String) {
        guard let snapshot = conversation(id: conversationID, for: .host) else { return }

        guard let (mutation, serverTask) = bookingCoordinator.submitBookingRequest(
            in: conversationID,
            eventDate: eventDate,
            note: note,
            snapshot: snapshot
        ) else { return }

        updateConversation(conversationID, mutate: mutation)

        Task { [weak self] in
            guard let self else { return }
            do {
                try await serverTask()
                await loadConversations(for: .host)
            } catch is CancellationError {
                // Normal task lifecycle
            } catch {
                restoreConversation(snapshot)
                loadingState = .failed(error.localizedDescription)
            }
        }
    }

    func acceptBooking(in conversationID: UUID) async {
        let index = await ensureConversationIndex(for: conversationID)
        await bookingCoordinator.acceptBooking(
            in: conversationID,
            conversationIndex: index,
            mutateConversations: { mutation in mutation(&conversations) },
            reloadConversations: { [weak self] in
                await self?.loadConversations(for: self?.sessionStore.currentRole ?? .host)
            },
            setLoadingState: { [weak self] state in self?.loadingState = state }
        )
    }

    func declineBooking(in conversationID: UUID, reason: String?) async {
        let index = await ensureConversationIndex(for: conversationID)
        await bookingCoordinator.declineBooking(
            in: conversationID,
            reason: reason,
            conversationIndex: index,
            mutateConversations: { mutation in mutation(&conversations) },
            reloadConversations: { [weak self] in
                await self?.loadConversations(for: self?.sessionStore.currentRole ?? .host)
            },
            setLoadingState: { [weak self] state in self?.loadingState = state }
        )
    }

    func requestPayment(in conversationID: UUID, amountCents: Int, note: String?, paymentType: PaymentType = .deposit, vendorEmail: String? = nil) async {
        let index = await ensureConversationIndex(for: conversationID)
        await bookingCoordinator.requestPayment(
            in: conversationID,
            amountCents: amountCents,
            note: note,
            paymentType: paymentType,
            vendorEmail: vendorEmail,
            conversationIndex: index,
            mutateConversations: { mutation in mutation(&conversations) },
            reloadConversations: { [weak self] in
                await self?.loadConversations(for: self?.sessionStore.currentRole ?? .host)
            },
            setLoadingState: { [weak self] state in self?.loadingState = state }
        )
    }

    func confirmPayment(in conversationID: UUID) async {
        await bookingCoordinator.confirmPayment(
            in: conversationID,
            mutateConversations: { mutation in mutation(&conversations) },
            findConversationIndex: { id in conversations.firstIndex(where: { $0.id == id }) },
            reloadConversations: { [weak self] in
                await self?.loadConversations(for: self?.sessionStore.currentRole ?? .host)
            }
        )
    }

    func vendorConfirmPayment(in conversationID: UUID) async {
        await bookingCoordinator.vendorConfirmPayment(
            in: conversationID,
            mutateConversations: { mutation in mutation(&conversations) },
            findConversationIndex: { id in conversations.firstIndex(where: { $0.id == id }) },
            reloadConversations: { [weak self] in
                await self?.loadConversations(for: self?.sessionStore.currentRole ?? .host)
            }
        )
    }

    func approveCancellationRequest(in conversationID: UUID) async {
        let index = await ensureConversationIndex(for: conversationID)
        await bookingCoordinator.respondToCancellationRequest(
            in: conversationID,
            approved: true,
            reason: nil,
            conversationIndex: index,
            mutateConversations: { mutation in mutation(&conversations) },
            reloadConversations: { [weak self] in
                await self?.loadConversations(for: self?.sessionStore.currentRole ?? .vendor)
            },
            setLoadingState: { [weak self] state in self?.loadingState = state }
        )
    }

    func declineCancellationRequest(in conversationID: UUID, reason: String?) async {
        let index = await ensureConversationIndex(for: conversationID)
        await bookingCoordinator.respondToCancellationRequest(
            in: conversationID,
            approved: false,
            reason: reason,
            conversationIndex: index,
            mutateConversations: { mutation in mutation(&conversations) },
            reloadConversations: { [weak self] in
                await self?.loadConversations(for: self?.sessionStore.currentRole ?? .vendor)
            },
            setLoadingState: { [weak self] state in self?.loadingState = state }
        )
    }

    func cancelBooking(in conversationID: UUID, reason: String?) {
        guard let snapshot = conversation(id: conversationID, for: sessionStore.currentRole) else { return }

        let currentStage = snapshot.stage

        // Post-payment (paid): server decides (direct cancel vs. cancellation_requested)
        // based on role, vendor policy, and deadline window.
        // Skip optimistic mutation because the outcome is uncertain.
        if currentStage == .paid {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let result = try await bookingService.cancelBooking(conversationID: conversationID, reason: reason)
                    let newStage = BookingStage.fromDatabaseValue(result.stage)
                    updateConversation(conversationID) { thread in
                        thread.stage = newStage
                        thread.lastActivityAt = .now
                        if newStage == .cancellationRequested {
                            thread.cancellationRequestDeadline = result.cancellationRequestDeadline
                            thread.cancellationRequestedByRole = sessionStore.currentRole
                        }
                    }
                    if newStage == .cancelled {
                        archiveConversation(conversationID, for: sessionStore.currentRole)
                    }
                    await loadConversations(for: sessionStore.currentRole)
                } catch is CancellationError {
                    // Normal task lifecycle
                } catch {
                    AppLogger.booking.error("Cancel booking (paid) failed: \(error.localizedDescription, privacy: .public)")
                    bookingActionError = error.localizedDescription
                }
            }
            return
        }

        // Pre-payment: always direct cancel, no approval needed
        let cancellingRole = sessionStore.currentRole
        let previousConflicts = dateConflictsByConversation[conversationID]

        let (mutation, serverTask) = bookingCoordinator.cancelBooking(
            in: conversationID,
            reason: reason,
            snapshot: snapshot,
            currentRole: cancellingRole,
            previousConflicts: previousConflicts
        )

        updateConversation(conversationID, mutate: mutation)
        dateConflictsByConversation[conversationID] = []
        archiveConversation(conversationID, for: cancellingRole)

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await serverTask()
                await loadConversations(for: cancellingRole)
                if sessionStore.currentRole == .vendor {
                    await refreshVendorDateConflicts(for: vendorScopedConversations())
                }
            } catch is CancellationError {
                // Normal task lifecycle
            } catch {
                restoreConversation(snapshot)
                dateConflictsByConversation[conversationID] = previousConflicts
                unarchiveConversation(conversationID, for: cancellingRole)
                AppLogger.booking.error("Cancel booking (pre-payment) failed: \(error.localizedDescription, privacy: .public)")
                bookingActionError = error.localizedDescription
            }
        }
    }

    func forceCancelBooking(in conversationID: UUID, reason: String?) {
        guard let snapshot = conversation(id: conversationID, for: sessionStore.currentRole) else { return }

        let cancellingRole = sessionStore.currentRole

        let (mutation, serverTask) = bookingCoordinator.forceCancelBooking(
            in: conversationID,
            reason: reason,
            snapshot: snapshot,
            currentRole: cancellingRole
        )

        updateConversation(conversationID, mutate: mutation)
        archiveConversation(conversationID, for: cancellingRole)

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await serverTask()
                await loadConversations(for: cancellingRole)
            } catch is CancellationError {
                // Normal task lifecycle
            } catch {
                restoreConversation(snapshot)
                unarchiveConversation(conversationID, for: cancellingRole)
                AppLogger.booking.error("Force cancel booking failed: \(error.localizedDescription, privacy: .public)")
                bookingActionError = error.localizedDescription
            }
        }
    }

    // MARK: - Date conflicts

    func refreshDateConflicts(in conversationID: UUID) async {
        guard let thread = conversation(id: conversationID, for: .vendor),
              let eventDate = thread.eventDate else {
            dateConflictsByConversation[conversationID] = []
            return
        }

        do {
            let conflicts = try await bookingService.checkVendorDateConflicts(vendorID: thread.vendorID, eventDate: eventDate)
                .filter { $0.conversationID != conversationID }
            dateConflictsByConversation[conversationID] = conflicts
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            AppLogger.booking.error("Failed to load date conflicts: \(error.localizedDescription, privacy: .public)")
        }
    }
}
