import SwiftUI

struct VendorBookingDetailSheet: View {
    let vendor: RequestsStore.VendorItem
    let onOpenChat: (UUID) -> Void
    let onViewProfile: (UUID) -> Void
    let onConfirmPayment: ((UUID) async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(InboxStore.self) private var inboxStore

    @State private var cancellationReason = ""
    @State private var isPresentingCancellationPrompt = false

    private var isConfirming: Bool {
        inboxStore.confirmingPaymentIDs.contains(vendor.conversationID)
    }

    private var conversation: ConversationThread? {
        inboxStore.conversation(id: vendor.conversationID, for: .host)
    }

    private var resolvedVendorProfile: VendorProfile? {
        inboxStore.vendorProfile(id: vendor.vendorID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    pricingRow
                    bookingDetails
                    stageExplanation
                    actions
                }
                .padding(AppTheme.screenPadding)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppBackdrop())
            .navigationTitle("Booking details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("Cancel booking", isPresented: $isPresentingCancellationPrompt) {
            TextField("Optional reason", text: $cancellationReason)

            Button("Keep booking", role: .cancel) {
                cancellationReason = ""
            }

            Button("Cancel booking", role: .destructive) {
                inboxStore.cancelBooking(
                    in: vendor.conversationID,
                    reason: cancellationReason.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
                cancellationReason = ""
            }
        } message: {
            cancellationPolicyMessage
        }
        .hapticFeedback(.warning, trigger: isPresentingCancellationPrompt) { _, new in new }
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: vendor.category.symbolName)
                .font(.title2)
                .foregroundStyle(AppTheme.toneColor(vendor.category.accentTone))

            VStack(alignment: .leading, spacing: 4) {
                Text(vendor.vendorName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(vendor.category.singularTitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            Spacer()

            StatusBadge(title: vendor.stage.title, tone: vendor.stage.tone)
        }
    }

    // MARK: - Pricing

    private var pricingRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "creditcard.fill")
                .font(.footnote)
            Text(vendor.priceLabel)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(AppTheme.Palette.subdued)
    }

    // MARK: - Booking Details

    @ViewBuilder
    private var bookingDetails: some View {
        if let conversation {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    if !conversation.eventDateLabel.isEmpty {
                        Label(conversation.eventDateLabel, systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    if !conversation.eventContextLine.isEmpty {
                        Label(conversation.eventContextLine, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    if let payment = conversation.paymentRequest {
                        Divider()

                        HStack {
                            Label(payment.amountLabel, systemImage: "banknote")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Spacer()

                            StatusBadge(
                                title: payment.status.title,
                                tone: payment.status.tone
                            )
                        }

                        if !payment.note.isEmpty {
                            Text(payment.note)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stage Explanation

    private var stageExplanation: some View {
        Text(stageDescription)
            .font(.footnote)
            .foregroundStyle(AppTheme.Palette.textSecondary)
    }

    private var stageDescription: String {
        switch vendor.stage {
        case .active:
            "Conversation is open — send a booking request to get started."
        case .requested:
            "Request sent — waiting for the vendor to review and respond."
        case .accepted:
            "Vendor accepted — review the quote and move to payment when ready."
        case .paymentRequested:
            "Payment requested — confirm the deposit to lock this booking."
        case .paid:
            "Payment confirmed — this vendor is locked in for your event."
        case .cancellationRequested:
            "Cancellation requested — awaiting vendor approval."
        case .declined:
            "Vendor declined this request."
        case .cancelled:
            "This booking has been cancelled."
        case .completed:
            "This booking is complete."
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            if vendor.stage == .paymentRequested, let onConfirmPayment {
                Button {
                    Task {
                        await onConfirmPayment(vendor.conversationID)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isConfirming {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                            Text("Confirming...")
                        } else {
                            Image(systemName: "checkmark.seal")
                            Text("Confirm Payment")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.toneColor(.sage))
                .disabled(isConfirming)
            }

            Button("Open chat", systemImage: "bubble.left.fill") {
                dismiss()
                onOpenChat(vendor.conversationID)
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button("View vendor profile", systemImage: "person.crop.rectangle") {
                dismiss()
                onViewProfile(vendor.vendorID)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            if vendor.stage.isCancellable {
                Button("Cancel booking", systemImage: "xmark.circle", role: .destructive) {
                    cancellationReason = ""
                    isPresentingCancellationPrompt = true
                }
                .buttonStyle(.borderless)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.toneColor(.coral))
            }
        }
    }

    // MARK: - Cancellation Policy

    @ViewBuilder
    private var cancellationPolicyMessage: some View {
        if vendor.stage != .paid {
            Text("No approval needed — no payment has been made.")
        } else if let profile = resolvedVendorProfile,
                  let days = profile.cancellationDeadlineDays,
                  let eventDate = conversation?.bookingEventDate,
                  eventDate.timeIntervalSinceNow <= Double(days) * 86_400 {
            Text("This vendor's cancellation policy requires their approval for cancellations within \(days) days of the event. Your request will be sent to the vendor.")
        } else {
            Text("This will cancel the booking. Your conversation history will still be available.")
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
