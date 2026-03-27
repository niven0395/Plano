import SwiftUI

struct VendorLeadDetailView: View {
    let summary: BookingRequestSummary

    @Environment(AppRouter.self) private var router
    @Environment(InboxStore.self) private var inboxStore
    @Environment(SessionStore.self) private var session
    @State private var declineReason = ""
    @State private var isPresentingDeclinePrompt = false
    @State private var cancellationReason = ""
    @State private var isPresentingCancellationPrompt = false
    @State private var isPresentingPaymentSheet = false
    @State private var isPresentingVendorConfirmPayment = false
    @State private var isLoadingLead = true
    @State private var vendorNoteText = ""
    @State private var vendorNoteSaveTask: Task<Void, Never>?

    private var conversationID: UUID? {
        summary.conversationID
    }

    private var conversation: ConversationThread? {
        guard let conversationID else { return nil }
        return inboxStore.conversation(id: conversationID, for: .vendor)
    }

    private var vendor: VendorProfile? {
        conversation.flatMap { inboxStore.vendorProfile(id: $0.vendorID) }
    }

    private var stage: BookingStage {
        conversation?.stage ?? summary.stage
    }

    private var bookingRequest: BookingRequestRecord? {
        guard let conversationID else { return nil }
        return inboxStore.bookingRequest(for: conversationID)
    }

    var body: some View {
        Group {
            if conversationID == nil {
                EmptyStateCard(
                    symbolName: "tray",
                    title: "Lead unavailable",
                    message: "This lead is missing the conversation context needed to open the brief."
                )
                .padding(AppTheme.screenPadding)
                .background(AppBackdrop())
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerCard
                        requestDetailsCard
                        vendorNotesCard
                        actionStack
                    }
                    .padding(AppTheme.screenPadding)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(AppBackdrop())
            }
        }
        .navigationTitle("Lead")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingPaymentSheet) {
            if let conversationID {
                VendorPaymentRequestSheet(
                    vendorName: vendor?.businessName ?? conversation?.vendorName ?? "Your business",
                    paymentMode: vendor?.paymentMode ?? .external,
                    vendorEmail: session.authenticatedProfile?.emailAddress
                ) { amountCents, note, paymentType in
                    Task {
                        await inboxStore.requestPayment(
                            in: conversationID,
                            amountCents: amountCents,
                            note: note,
                            paymentType: paymentType,
                            vendorEmail: session.authenticatedProfile?.emailAddress
                        )
                    }
                }
            }
        }
        .task(id: conversationID) {
            await loadLeadIfNeeded()
        }
        .alert("Cancel booking", isPresented: $isPresentingCancellationPrompt) {
            TextField("Optional reason", text: $cancellationReason)
            Button("Keep booking", role: .cancel) {
                cancellationReason = ""
            }
            Button("Cancel booking", role: .destructive) {
                if let conversationID {
                    inboxStore.cancelBooking(in: conversationID, reason: cancellationReason.nilIfEmpty)
                }
                cancellationReason = ""
            }
        } message: {
            if stage == .paid {
                Text("The host will be asked to approve this cancellation since payment has been confirmed.")
            } else {
                Text("This will cancel the booking. The host will be notified.")
            }
        }
        .alert("Decline request", isPresented: $isPresentingDeclinePrompt) {
            TextField("Optional reason", text: $declineReason)

            Button("Keep request", role: .cancel) {
                declineReason = ""
            }

            Button("Decline", role: .destructive) {
                if let conversationID {
                    Task {
                        await inboxStore.declineBooking(
                            in: conversationID,
                            reason: declineReason.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        )
                    }
                }
                declineReason = ""
            }
        } message: {
            Text("This keeps the history intact while moving the request to declined.")
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

    private var headerCard: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(conversation?.hostName ?? summary.counterpartName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(conversation?.eventTitle ?? summary.eventTitle)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer(minLength: 16)

                    StatusBadge(title: (conversation?.stage ?? summary.stage).title, tone: (conversation?.stage ?? summary.stage).tone)
                }

                VStack(alignment: .leading, spacing: 10) {
                    LeadOverviewRow(
                        label: conversation?.eventDateLabel ?? summary.eventDateLabel,
                        systemImage: "calendar"
                    )

                    if let contextLine = conversation?.eventContextLine, !contextLine.isEmpty {
                        LeadOverviewRow(label: contextLine, systemImage: "mappin.and.ellipse")
                    }

                    LeadOverviewRow(
                        label: "Recently received",
                        systemImage: "paperplane.fill"
                    )
                }

                Text(conversation == nil ? summary.detail : inboxStore.updatedSummary(from: summary, for: .vendor).detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var requestDetailsCard: some View {
        if isLoadingLead {
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
        } else if !requestDetailRows.isEmpty || !requestNote.isEmpty || !intakeAnswerRows.isEmpty {
            AppSurface {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Request details")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(requestDetailRows) { row in
                            detailRow(title: row.title, value: row.value)
                        }
                    }

                    if !requestNote.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Customer note")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)

                            Text(requestNote)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !intakeAnswerRows.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Requested details")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)

                            ForEach(intakeAnswerRows) { row in
                                detailRow(title: row.title, value: row.value)
                            }
                        }
                    }
                }
            }
        }
    }

    private var vendorNotesCard: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("Your notes")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Only visible to you")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Palette.subdued.opacity(0.12), in: Capsule())
                }

                TextEditor(text: $vendorNoteText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .task(id: vendorNoteText) {
                        vendorNoteSaveTask?.cancel()
                        let content = vendorNoteText
                        guard let conversationID else { return }
                        vendorNoteSaveTask = Task {
                            try? await Task.sleep(for: .seconds(1))
                            guard !Task.isCancelled else { return }
                            await inboxStore.saveVendorNote(for: conversationID, content: content)
                        }
                    }
            }
        }
    }

    private var actionStack: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Next step")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(actionSummary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let paymentRequest, stage == .paymentRequested || stage == .paid {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        detailRow(
                            title: stage == .paid ? "Payment received" : "Requested amount",
                            value: paymentRequest.amountLabel
                        )

                        if let requestedAt = paymentRequest.requestedAt, stage == .paymentRequested {
                            detailRow(
                                title: "Requested",
                                value: requestedAt.formatted(.dateTime.month().day().hour().minute())
                            )
                        }

                        if !paymentRequest.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            detailRow(title: "Payment instructions", value: paymentRequest.note)
                        }
                    }
                }

                actionButtons
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch stage {
        case .requested:
            Button("Accept request") {
                guard let conversationID else { return }
                Task {
                    await inboxStore.acceptBooking(in: conversationID)
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button("Reply in chat") {
                openConversation()
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(conversationID == nil)

            Button("Decline request", role: .destructive) {
                declineReason = ""
                isPresentingDeclinePrompt = true
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.toneColor(.coral))

        case .accepted:
            Button("Request payment") {
                isPresentingPaymentSheet = true
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button("Reply in chat") {
                openConversation()
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(conversationID == nil)

            Button("Cancel booking", role: .destructive) {
                cancellationReason = ""
                isPresentingCancellationPrompt = true
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.toneColor(.coral))

        case .paymentRequested:
            Button("Open payment thread") {
                openConversation()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(conversationID == nil)

            Button("Confirm payment received") {
                isPresentingVendorConfirmPayment = true
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(conversationID == nil)
            .confirmationDialog(
                "Confirm payment received",
                isPresented: $isPresentingVendorConfirmPayment,
                titleVisibility: .visible
            ) {
                Button("Confirm received") {
                    if let conversationID {
                        Task {
                            await inboxStore.vendorConfirmPayment(in: conversationID)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This marks the payment as received and locks in the booking. Only confirm if you have received the funds.")
            }

            Button("Cancel booking", role: .destructive) {
                cancellationReason = ""
                isPresentingCancellationPrompt = true
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.toneColor(.coral))

        case .cancellationRequested:
            Button("Review cancellation") {
                openConversation()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(conversationID == nil)

        case .paid:
            Button("Reply in chat") {
                openConversation()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(conversationID == nil)

            Button("Cancel booking", role: .destructive) {
                cancellationReason = ""
                isPresentingCancellationPrompt = true
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.toneColor(.coral))

        case .active, .declined, .cancelled, .completed:
            Button("Reply in chat") {
                openConversation()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(conversationID == nil)
        }
    }

    private var actionSummary: String {
        switch stage {
        case .requested:
            return "This customer is waiting on your decision. Accept the request to move it forward, or decline it with a short reason."
        case .accepted:
            switch vendor?.paymentMode ?? .external {
            case .platform:
                return "The request is accepted. Send the payment amount so the customer can complete the deposit on Plano."
            case .cashOnly:
                return "The request is accepted. Send the amount and payment instructions so the customer knows how to pay you."
            case .external:
                return "The request is accepted. Send the amount with your e-transfer details, or edit the note if you want to collect cash instead."
            }
        case .paymentRequested:
            return "Payment has been requested. Use this chat so the customer can confirm payment in one place."
        case .paid:
            return "Payment is confirmed. Use chat for timeline details, setup notes, and any final coordination."
        case .cancellationRequested:
            return "The host has requested to cancel this booking. Review the request and approve or decline it."
        case .declined:
            return "This request has been declined. The conversation stays available if either side needs to clarify anything."
        case .cancelled:
            return "This booking is cancelled. Any final details can be shared in the conversation."
        case .completed:
            return "The event is complete. Keep any final wrap-up or delivery notes here."
        case .active:
            return "Use chat to qualify the lead, then accept the request once you have what you need."
        }
    }

    private var requestDetailRows: [DetailRow] {
        if let bookingRequest {
            var rows: [DetailRow] = []

            let partyType = (conversation?.eventTitle ?? summary.eventTitle).trimmingCharacters(in: .whitespacesAndNewlines)
            if !partyType.isEmpty, partyType != "Direct inquiry" {
                rows.append(DetailRow("Party type", partyType))
            }

            if let eventDate = bookingRequest.eventDate {
                rows.append(DetailRow("Event date", eventDate.formatted(.dateTime.month().day().year())))
            } else if !summary.eventDateLabel.isEmpty, summary.eventDateLabel != "Date pending" {
                rows.append(DetailRow("Event date", summary.eventDateLabel))
            }

            if let guestCountLabel = bookingRequest.guestCountLabel,
               !guestCountLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rows.append(DetailRow("Guest count", guestCountLabel))
            }

            if let requestedServices = bookingRequest.requestedServices,
               !requestedServices.isEmpty {
                rows.append(DetailRow("Services", requestedServices.joined(separator: " · ")))
            }

            if let budgetLabel = bookingRequest.budgetLabel,
               !budgetLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rows.append(DetailRow("Budget", budgetLabel))
            }

            if let responseWindowLabel = bookingRequest.responseWindowLabel,
               !responseWindowLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rows.append(DetailRow("Response window", responseWindowLabel))
            }

            return rows
        }

        return [
            DetailRow("Party type", summary.eventTitle),
            DetailRow("Event date", summary.eventDateLabel),
        ]
        .filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var requestNote: String {
        bookingRequest?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var paymentRequest: PaymentRequest? {
        conversation?.paymentRequest
    }

    private var intakeAnswerRows: [DetailRow] {
        guard let bookingRequest else { return [] }

        let answers = (bookingRequest.intakeAnswers ?? [])
            .filter(\.hasValue)

        guard !answers.isEmpty else { return [] }

        let orderedQuestionIDs = vendor?.enabledLeadIntakeQuestions.map(\.id) ?? []
        let promptByQuestionID = Dictionary(
            uniqueKeysWithValues: (vendor?.enabledLeadIntakeQuestions ?? []).map { question in
                (question.id, question.trimmedPrompt.isEmpty ? question.prompt : question.trimmedPrompt)
            }
        )

        return answers
            .sorted { lhs, rhs in
                let lhsIndex = orderedQuestionIDs.firstIndex(of: lhs.questionID) ?? .max
                let rhsIndex = orderedQuestionIDs.firstIndex(of: rhs.questionID) ?? .max
                return lhsIndex < rhsIndex
            }
            .map { answer in
                let prompt = promptByQuestionID[answer.questionID]
                    ?? answer.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                return DetailRow(
                    prompt.isEmpty ? "Requested detail" : prompt,
                    answer.displayValue
                )
            }
    }

    private func loadLeadIfNeeded() async {
        guard let conversationID else { return }
        if conversation != nil, bookingRequest != nil {
            isLoadingLead = false
        } else {
            isLoadingLead = true
            _ = await inboxStore.ensureConversationLoaded(conversationID, for: .vendor)
            isLoadingLead = false
        }
        await inboxStore.loadVendorNote(for: conversationID)
        vendorNoteText = inboxStore.vendorNotes[conversationID] ?? ""
    }

    private func openConversation() {
        guard let conversationID else { return }
        router.openConversation(conversationID)
        Task {
            _ = await inboxStore.ensureConversationLoaded(conversationID, for: .vendor)
            await inboxStore.loadMessages(for: conversationID)
        }
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

private struct DetailRow: Identifiable {
    let id: String
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.id = title
        self.title = title
        self.value = value
    }
}

private struct LeadOverviewRow: View {
    let label: String
    let systemImage: String

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Palette.subdued)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
