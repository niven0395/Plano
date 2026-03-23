import SwiftUI

struct ConversationView: View {
    let conversationID: UUID

    @Environment(InboxStore.self) private var inboxStore
    @Environment(SessionStore.self) private var session
    @State private var isRecoveringConversation = false
    @State private var hasAttemptedRecovery = false

    var body: some View {
        Group {
            if let conversation = inboxStore.conversation(id: conversationID, for: session.currentRole) {
                let vendor = inboxStore.vendorProfile(id: conversation.vendorID)

                ConversationContentView(
                    conversation: conversation,
                    vendor: vendor,
                    conversationID: conversationID
                )
            } else if !hasAttemptedRecovery || isRecoveringConversation {
                AppSurface {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(AppTheme.Palette.accent)

                        Text("Loading conversation…")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                    .padding(.vertical, 6)
                }
                .padding(AppTheme.screenPadding)
                .background(AppBackdrop())
                .navigationTitle("Conversation")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                EmptyStateCard(
                    symbolName: "bubble.left.and.bubble.right",
                    title: "Conversation unavailable",
                    message: "This thread is no longer visible for the active role."
                )
                .padding(AppTheme.screenPadding)
                .background(AppBackdrop())
                .navigationTitle("Conversation")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: conversationID) {
            hasAttemptedRecovery = false
            await recoverConversationIfNeeded()
            await inboxStore.loadMessages(for: conversationID)
        }
    }

    private func recoverConversationIfNeeded() async {
        guard inboxStore.conversation(id: conversationID, for: session.currentRole) == nil else {
            hasAttemptedRecovery = true
            isRecoveringConversation = false
            return
        }

        guard !isRecoveringConversation else { return }
        isRecoveringConversation = true
        _ = await inboxStore.ensureConversationLoaded(conversationID, for: session.currentRole)
        isRecoveringConversation = false
        hasAttemptedRecovery = true
    }
}

struct ConversationContextCard: View {
    let eventTitle: String
    let eventContextLine: String
    let stage: BookingStage
    let eventDateLabel: String
    let vendorName: String
    let vendorCategory: VendorCategory

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(eventTitle)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(eventContextLine)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer()

                    StatusBadge(title: stage.title, tone: stage.tone)
                }

                HStack(spacing: 14) {
                    Label(eventDateLabel, systemImage: "calendar")
                    Label(vendorName, systemImage: vendorCategory.symbolName)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

                Text("Messages, booking state, and payment status stay anchored to this event so the handoff never loses context.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }
}

struct ConversationBookingStatusBanner: View {
    let thread: ConversationThread
    let role: UserRole
    @Binding var isPresentingDeclinePrompt: Bool
    @Binding var isPresentingPaymentSheet: Bool
    @Binding var isPresentingCancellationApproval: Bool
    @Binding var isPresentingCancellationDeclinePrompt: Bool
    @Binding var isPresentingForceCancelPrompt: Bool

    @Environment(InboxStore.self) private var inboxStore

    private var isCounterpartyRequest: Bool {
        guard let requestedByRole = thread.cancellationRequestedByRole else { return false }
        return requestedByRole != role
    }

    private var isOwnDeclinedRequest: Bool {
        guard let requestedByRole = thread.cancellationRequestedByRole else { return false }
        return requestedByRole == role && thread.cancellationDeclinedAt != nil
    }

    var body: some View {
        switch thread.stage {
        case .active:
            EmptyView()
        case .requested:
            if role == .vendor {
                VStack(spacing: 12) {
                    Label("Booking requested", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.medium))
                    if let date = thread.bookingEventDate {
                        Text(date, format: .dateTime.month(.wide).day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button("Decline") { isPresentingDeclinePrompt = true }
                            .buttonStyle(.bordered)
                        Button("Accept") {
                            Task { await inboxStore.acceptBooking(in: thread.id) }
                        }
                        .buttonStyle(.borderedProminent)
                        .sensoryFeedback(.success, trigger: thread.stage) { old, _ in
                            old == .requested
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                Label("Request sent — waiting for vendor", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        case .accepted:
            if role == .vendor {
                VStack(spacing: 12) {
                    Label("Booking accepted", systemImage: "checkmark.circle")
                        .font(.subheadline.weight(.medium))
                    Button("Request Payment") { isPresentingPaymentSheet = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                Label("Accepted — vendor may request payment", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        case .paymentRequested:
            if role == .host, let payment = thread.paymentRequest {
                VStack(spacing: 10) {
                    Label("\(payment.paymentType.messagePrefix) requested: \(payment.amountLabel)", systemImage: "dollarsign.circle")
                        .font(.subheadline.weight(.medium))

                    ConfirmPaymentButton(conversationID: thread.id)
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                Label("Awaiting payment", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        case .paid:
            VStack(spacing: 8) {
                Label("Payment confirmed", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
                if isOwnDeclinedRequest {
                    Text("Your cancellation request was declined.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Cancel anyway", role: .destructive) {
                        isPresentingForceCancelPrompt = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
            .padding()
        case .cancellationRequested:
            if isCounterpartyRequest {
                VStack(spacing: 12) {
                    Label("Cancellation requested", systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.medium))
                    Text(role == .vendor
                         ? "The host has requested to cancel this booking."
                         : "The vendor has requested to cancel this booking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let deadline = thread.cancellationRequestDeadline {
                        Text("Auto-resolves \(deadline, format: .relative(presentation: .named))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 12) {
                        Button("Decline") { isPresentingCancellationDeclinePrompt = true }
                            .buttonStyle(.bordered)
                        Button("Approve Cancellation") { isPresentingCancellationApproval = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    Label("Cancellation requested — awaiting approval", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let deadline = thread.cancellationRequestDeadline {
                        Text("Auto-resolves \(deadline, format: .relative(presentation: .named))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
            }
        case .declined:
            Label("Declined", systemImage: "xmark.circle")
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding()
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle")
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding()
        case .completed:
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
                .padding()
        }
    }
}

struct ConversationComposerBar: View {
    let conversationID: UUID
    let currentRole: UserRole
    @Bindable var inboxStore: InboxStore
    var isComposerFocused: FocusState<Bool>.Binding
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var sendHapticTrigger = false
    @State private var draftText: String = ""

    var body: some View {
        let canSend = !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty

        VStack(spacing: 0) {
            Divider()
                .overlay(AppTheme.Palette.border)

            VStack(spacing: 8) {
                PendingAttachmentPreviewRow(attachments: pendingAttachments) { attachment in
                    pendingAttachments.removeAll { $0.id == attachment.id }
                }

                HStack(alignment: .bottom, spacing: 8) {
                    AttachmentPickerButton(selectedAttachments: $pendingAttachments)
                        .frame(height: AppTheme.avatarSize)

                    TextField("Send a message", text: $draftText, axis: .vertical)
                        .focused(isComposerFocused)
                        .lineLimit(1...5)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
                        .onChange(of: draftText) { _, newValue in
                            inboxStore.updateDraft(newValue, for: conversationID, role: currentRole)
                            inboxStore.sendTypingIndicator(for: conversationID, as: currentRole)
                        }

                    Button {
                        if !pendingAttachments.isEmpty {
                            let body = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                            let attachments = pendingAttachments
                            draftText = ""
                            inboxStore.updateDraft("", for: conversationID, role: currentRole)
                            pendingAttachments = []
                            inboxStore.sendMessageWithAttachments(
                                body,
                                attachments: attachments,
                                in: conversationID,
                                as: currentRole
                            )
                            isComposerFocused.wrappedValue = false
                            sendHapticTrigger.toggle()
                        } else if inboxStore.sendDraft(in: conversationID, as: currentRole) {
                            draftText = ""
                            isComposerFocused.wrappedValue = false
                            sendHapticTrigger.toggle()
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.accentForeground)
                            .frame(width: AppTheme.avatarSize, height: AppTheme.avatarSize)
                            .background(canSend ? AppTheme.Palette.accent : AppTheme.Palette.subdued.opacity(0.6), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .accessibilityLabel("Send message")
                    .hapticFeedback(.impact(weight: .medium), trigger: sendHapticTrigger)
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(AppTheme.Palette.elevatedSurface)
        }
        .onAppear {
            draftText = inboxStore.draft(for: conversationID, role: currentRole)
        }
    }
}

private struct DeliveryStatusIndicator: View {
    let status: MessageDeliveryStatus

    var body: some View {
        switch status {
        case .sending:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(AppTheme.Palette.subdued)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(AppTheme.Palette.subdued)
        case .delivered:
            Image(systemName: "checkmark")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.Palette.subdued)
        case .read:
            Image(systemName: "checkmark")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.Palette.accent)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(Color.red)
        }
    }
}

private struct ConflictWarningCard: View {
    let conflicts: [DateConflict]
    let eventDateLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.toneColor(.gold))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Same-date booking overlap")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("You have \(conflicts.count) other active booking\(conflicts.count == 1 ? "" : "s") on \(eventDateLabel).")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }

            Text(conflicts.map(\.eventTitle).joined(separator: " · "))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.toneColor(.gold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.toneColor(.gold).opacity(0.12), in: .rect(cornerRadius: AppTheme.smallCornerRadius))
    }
}

struct MessageRow: View {
    let message: ChatMessage
    let conversation: ConversationThread
    let currentRole: UserRole

    var body: some View {
        switch message.kind {
        case .text:
            if message.sender == .system {
                systemMessageRow
            } else {
                contentRow {
                    Text(message.body)
                        .font(.body)
                        .foregroundStyle(isCurrentUser ? AppTheme.Palette.accentForeground : AppTheme.Palette.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(isCurrentUser ? AnyShapeStyle(AppTheme.Palette.accent) : AnyShapeStyle(AppTheme.Palette.elevatedSurface), in: RoundedRectangle(cornerRadius: 24))
                }
            }

        case .system:
            systemMessageRow

        case .paymentRequest:
            contentRow {
                let paymentStatus = conversation.paymentRequest?.status ?? .pending
                let isConfirmed = paymentStatus == .paid || conversation.stage == .paid
                let title = isConfirmed ? "Payment confirmed" : "Payment request"
                let symbolName = isConfirmed ? "checkmark.seal.fill" : "dollarsign.circle"
                let tone: AccentTone = isConfirmed ? .sage : .blue
                let bodyText: String = if isConfirmed, let payment = conversation.paymentRequest {
                    "\(payment.paymentType.messagePrefix) of \(payment.amountLabel) confirmed."
                } else {
                    message.body
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Label(title, systemImage: symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.toneColor(tone))

                        if let payment = conversation.paymentRequest {
                            Text(payment.paymentType.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.toneColor(tone))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.toneColor(tone).opacity(0.12), in: Capsule())
                        }
                    }

                    Text(bodyText)
                        .font(.body)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    if let payment = conversation.paymentRequest,
                       let email = payment.vendorEmail,
                       !email.isEmpty {
                        HStack(spacing: 8) {
                            Label(email, systemImage: "envelope")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Button {
                                UIPasteboard.general.string = email
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.toneColor(tone))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Copy vendor email")
                        }
                    }

                    if let payment = conversation.paymentRequest,
                       !payment.note.isEmpty {
                        Text(payment.note)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    if currentRole == .host, !isConfirmed {
                        ConfirmPaymentButton(conversationID: conversation.id)
                    }
                }
                .padding(16)
                .background(AppTheme.toneBackground(tone), in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppTheme.toneColor(tone).opacity(0.16), lineWidth: 1)
                }
            }

        case .attachment:
            contentRow {
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                    if !message.body.isEmpty && !message.body.starts(with: "Sent ") {
                        Text(message.body)
                            .font(.body)
                            .foregroundStyle(isCurrentUser ? AppTheme.Palette.accentForeground : AppTheme.Palette.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(isCurrentUser ? AnyShapeStyle(AppTheme.Palette.accent) : AnyShapeStyle(AppTheme.Palette.elevatedSurface), in: RoundedRectangle(cornerRadius: 24))
                    }

                    ForEach(message.attachments) { attachment in
                        AttachmentBubbleView(attachment: attachment, isCurrentUser: isCurrentUser)
                    }
                }
            }
        }
    }

    private var systemMessageRow: some View {
        HStack {
            Spacer()

            Text(message.body)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.Palette.elevatedSurface, in: Capsule())

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func contentRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isCurrentUser {
                Spacer(minLength: 56)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                Text(senderLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)

                content()

                HStack(spacing: 4) {
                    Text(message.sentAt.formatted(.dateTime.hour().minute()))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.subdued)

                    if isCurrentUser {
                        DeliveryStatusIndicator(status: message.status)
                    }
                }
            }

            if !isCurrentUser {
                Spacer(minLength: 56)
            }
        }
    }

    private var isCurrentUser: Bool {
        switch message.sender.userRole {
        case .some(let role):
            role == currentRole
        case .none:
            false
        }
    }

    private var senderLabel: String {
        switch message.sender {
        case .host:
            conversation.hostName
        case .vendor:
            conversation.vendorName
        case .system:
            "System"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ConfirmPaymentButton: View {
    let conversationID: UUID

    @Environment(InboxStore.self) private var inboxStore

    private var isConfirming: Bool {
        inboxStore.confirmingPaymentIDs.contains(conversationID)
    }

    var body: some View {
        Button {
            Task {
                await inboxStore.confirmPayment(in: conversationID)
            }
        } label: {
            HStack(spacing: 8) {
                if isConfirming {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text("Confirming…")
                } else {
                    Image(systemName: "checkmark.seal")
                    Text("Confirm Payment")
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.toneColor(.sage))
        .disabled(isConfirming)
        .hapticFeedback(.success, trigger: isConfirming) { old, new in
            old && !new
        }
    }
}

struct TypingIndicatorRow: View {
    let name: String

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppTheme.Palette.subdued.opacity(0.7))
                        .frame(width: AppTheme.badgeSize, height: AppTheme.badgeSize)
                        .scaleEffect(0.85 + (Double(index) * 0.05))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.Palette.elevatedSurface, in: Capsule())

            Text("\(name) is typing...")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

            Spacer()
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
