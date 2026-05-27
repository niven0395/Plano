import SwiftUI

struct BookingDetailView: View {
    let conversationID: UUID

    @Environment(AppRouter.self) private var router
    @Environment(InboxStore.self) private var inboxStore
    @Environment(SessionStore.self) private var session

    @State private var isLoading = true
    @State private var cancellationReason = ""
    @State private var isPresentingCancellation = false

    private var thread: ConversationThread? {
        inboxStore.conversation(id: conversationID, for: .host)
    }

    private var stage: BookingStage {
        thread?.stage ?? .requested
    }

    private var bookingRequest: BookingRequestRecord? {
        inboxStore.bookingRequest(for: conversationID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let thread {
                    vendorHeader(thread)
                    eventDetailsCard(thread)
                    requestDetailsCard
                    paymentCard(thread)
                } else if isLoading {
                    loadingState
                } else {
                    EmptyStateCard(
                        symbolName: "tray",
                        title: "Booking unavailable",
                        message: "This booking could not be loaded."
                    )
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, thread != nil ? 96 : 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if thread != nil, stage.isCancellable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel booking", role: .destructive) {
                        cancellationReason = ""
                        isPresentingCancellation = true
                    }
                    .foregroundStyle(AppTheme.toneColor(.coral))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if thread != nil {
                AppFloatingActionBar {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Booking")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.subdued)
                            .textCase(.uppercase)
                            .tracking(0.4)
                        Text(stage.title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.toneColor(stage.tone))
                            .lineLimit(1)
                    }
                } trailing: {
                    Button(action: openConversation) {
                        Label("Message vendor", systemImage: "bubble.left.fill")
                    }
                    .buttonStyle(AppFloatingActionBarButtonStyle())
                    .accessibilityLabel("Message vendor")
                }
            }
        }
        .task(id: conversationID) {
            await loadIfNeeded()
        }
        .alert("Cancel booking", isPresented: $isPresentingCancellation) {
            TextField("Optional reason", text: $cancellationReason)
            Button("Keep booking", role: .cancel) {
                cancellationReason = ""
            }
            Button("Cancel booking", role: .destructive) {
                inboxStore.cancelBooking(in: conversationID, reason: cancellationReason.trimmedOrNil)
                cancellationReason = ""
            }
        } message: {
            if stage == .paid {
                Text("The vendor will need to approve this cancellation since payment has been confirmed.")
            } else {
                Text("This will cancel the booking. The vendor will be notified.")
            }
        }
        .alert(
            "Action failed",
            isPresented: Binding(
                get: { inboxStore.bookingActionError != nil },
                set: { if !$0 { inboxStore.bookingActionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(inboxStore.bookingActionError ?? "Something went wrong. Please try again.")
        }
    }

    // MARK: - Vendor Header

    private func vendorHeader(_ thread: ConversationThread) -> some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(thread.vendorName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Label(thread.vendorCategory.singularTitle, systemImage: thread.vendorCategory.symbolName)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer(minLength: 16)

                    StatusBadge(title: stage.title, tone: stage.tone)
                }

                Text(hostStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Event Details

    private func eventDetailsCard(_ thread: ConversationThread) -> some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                Text("Event details")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                VStack(alignment: .leading, spacing: 12) {
                    if !thread.eventTitle.isEmpty, thread.eventTitle != "Direct inquiry" {
                        detailRow(title: "Event", value: thread.eventTitle)
                    }

                    if !thread.eventDateLabel.isEmpty {
                        detailRow(title: "Date", value: thread.eventDateLabel)
                    }

                    if let timeRange = thread.timeRangeLabel, !timeRange.isEmpty {
                        detailRow(title: "Time", value: timeRange)
                    }

                    if let venue = thread.venueSettingLabel, !venue.isEmpty {
                        detailRow(title: "Venue", value: venue)
                    }

                    if !thread.eventContextLine.isEmpty {
                        detailRow(title: "Location", value: thread.eventContextLine)
                    }
                }
            }
        }
    }

    // MARK: - Request Details

    @ViewBuilder
    private var requestDetailsCard: some View {
        if isLoading {
            AppSurface {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(AppTheme.Palette.accent)

                    Text("Loading request details…")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
                .padding(.vertical, 6)
            }
        } else if !requestDetailRows.isEmpty || !requestNote.isEmpty {
            AppSurface {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your request")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(requestDetailRows, id: \.title) { row in
                            detailRow(title: row.title, value: row.value)
                        }
                    }

                    if !requestNote.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your note")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)

                            Text(requestNote)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Payment

    @ViewBuilder
    private func paymentCard(_ thread: ConversationThread) -> some View {
        if let paymentRequest = thread.paymentRequest {
            AppSurface(style: .highlighted) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Payment")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    detailRow(
                        title: stage == .paid ? "Amount paid" : "Amount requested",
                        value: paymentRequest.amountLabel
                    )

                    if !paymentRequest.note.isEmpty {
                        detailRow(title: "Note from vendor", value: paymentRequest.note)
                    }

                    if stage == .paymentRequested {
                        Button("Confirm payment") {
                            Task {
                                await inboxStore.confirmPayment(in: conversationID)
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        AppSurface {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(AppTheme.Palette.accent)

                Text("Loading booking…")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Helpers

    private var hostStatusMessage: String {
        switch stage {
        case .active:
            "Chat with the vendor to discuss your needs."
        case .requested:
            "Your request has been sent. Waiting for the vendor to respond."
        case .accepted:
            "The vendor has confirmed your booking. They may send payment details next."
        case .paymentRequested:
            "The vendor has requested payment. Review the amount and confirm when ready."
        case .paid:
            "Payment is confirmed. You're all set for the event."
        case .cancellationRequested:
            "A cancellation has been requested. The vendor will review it."
        case .declined:
            "This request was declined by the vendor."
        case .cancelled:
            "This booking has been cancelled."
        case .completed:
            "This event is complete."
        }
    }

    private var requestDetailRows: [(title: String, value: String)] {
        guard let bookingRequest else { return [] }

        var rows: [(title: String, value: String)] = []

        if let eventDate = bookingRequest.eventDate {
            rows.append(("Event date", eventDate.formatted(.dateTime.month().day().year())))
        }

        if let guestCount = bookingRequest.guestCountLabel,
           !guestCount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(("Guest count", guestCount))
        }

        if let services = bookingRequest.requestedServices, !services.isEmpty {
            rows.append(("Services", services.joined(separator: " · ")))
        }

        if let budget = bookingRequest.budgetLabel,
           !budget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(("Budget", budget))
        }

        return rows
    }

    private var requestNote: String {
        bookingRequest?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func loadIfNeeded() async {
        if thread != nil, bookingRequest != nil {
            isLoading = false
        } else {
            isLoading = true
            _ = await inboxStore.ensureConversationLoaded(conversationID, for: .host)
            isLoading = false
        }
    }

    private func openConversation() {
        router.openConversation(conversationID)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension String {
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
