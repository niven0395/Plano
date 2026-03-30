import SwiftUI

struct ConversationContentView: View {
    let conversation: ConversationThread
    let vendor: VendorProfile?
    let conversationID: UUID

    @Environment(InboxStore.self) private var inboxStore
    @Environment(SessionStore.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(RealtimeManager.self) private var realtimeManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(EventWorkspaceStore.self) private var workspaceStore
    @FocusState private var isComposerFocused: Bool
    @State private var declineReason = ""
    @State private var cancellationReason = ""
    @State private var cancellationDeclineReason = ""
    @State private var isPresentingDeclinePrompt = false
    @State private var isPresentingCancellationPrompt = false
    @State private var isPresentingPaymentSheet = false
    @State private var isPresentingCancellationApproval = false
    @State private var isPresentingCancellationDeclinePrompt = false
    @State private var isPresentingForceCancelPrompt = false
    @State private var sendHapticTrigger = false

    private let bottomAnchorID = "conversation-bottom-anchor"

    var body: some View {
        let isTyping = inboxStore.isCounterpartTyping(in: conversationID, for: session.currentRole)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ConnectionStatusBanner(
                        connectionState: realtimeManager.connectionState,
                        isNetworkConnected: networkMonitor.isConnected,
                        hasEverConnected: realtimeManager.hasEverConnected
                    )

                    if conversation.eventID != nil {
                        ConversationContextCard(
                            eventTitle: conversation.eventTitle,
                            eventContextLine: conversation.eventContextLine,
                            stage: conversation.stage,
                            eventDateLabel: conversation.eventDateLabel,
                            vendorName: conversation.vendorName,
                            vendorCategory: conversation.vendorCategory
                        )
                    }

                    if session.currentRole == .vendor,
                       conversation.stage.isConfirmed,
                       conversation.eventID != nil {
                        let count = workspaceStore.coVendorCount(for: conversation.eventID)
                        if count > 0 {
                            Button {
                                if let eventID = conversation.eventID {
                                    router.openVendorEventWorkspace(eventID)
                                }
                            } label: {
                                AppSurface {
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.2.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.toneColor(.blue))

                                        Text("\(count) other vendor\(count == 1 ? "" : "s") confirmed")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(AppTheme.Palette.textPrimary)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(AppTheme.Palette.subdued)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ConversationBookingStatusBanner(
                        thread: conversation,
                        role: session.currentRole,
                        isPresentingDeclinePrompt: $isPresentingDeclinePrompt,
                        isPresentingPaymentSheet: $isPresentingPaymentSheet,
                        isPresentingCancellationApproval: $isPresentingCancellationApproval,
                        isPresentingCancellationDeclinePrompt: $isPresentingCancellationDeclinePrompt,
                        isPresentingForceCancelPrompt: $isPresentingForceCancelPrompt
                    )

                    LazyVStack(spacing: 14) {
                        if conversation.isLoadingMessages && !conversation.hasLoadedInitialMessages {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(AppTheme.Palette.accent)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        }

                        if conversation.hasOlderMessages {
                            Button {
                                Task {
                                    await inboxStore.loadOlderMessages(for: conversationID)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if conversation.isLoadingMessages {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text("Load earlier messages")
                                        .font(.footnote.weight(.semibold))
                                }
                                .foregroundStyle(AppTheme.Palette.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                            .disabled(conversation.isLoadingMessages)
                        }

                        ForEach(conversation.messages) { message in
                            MessageRow(
                                message: message,
                                conversation: conversation,
                                currentRole: session.currentRole
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }

                        if isTyping {
                            TypingIndicatorRow(name: conversation.counterpartName(for: session.currentRole))
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .animation(AppAnimation.transition, value: conversation.messages.count)
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 18)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackdrop())
            .safeAreaInset(edge: .bottom) {
                ConversationComposerBar(
                    conversationID: conversationID,
                    currentRole: session.currentRole,
                    inboxStore: inboxStore,
                    isComposerFocused: $isComposerFocused
                )
            }
            .onTapGesture {
                isComposerFocused = false
            }
            .onAppear {
                inboxStore.markConversationRead(conversationID, for: session.currentRole)
                scrollToBottom(using: proxy, animated: false)
            }
            .task(id: conversationID) {
                guard session.currentRole == .vendor else { return }
                await inboxStore.refreshDateConflicts(in: conversationID)
            }
            .onChange(of: conversation.messages.count) { _, _ in
                inboxStore.markConversationRead(conversationID, for: session.currentRole)
                scrollToBottom(using: proxy)
            }
            .onChange(of: isTyping) { _, _ in
                scrollToBottom(using: proxy)
            }
            .onChange(of: isComposerFocused) { _, focused in
                if focused {
                    scrollToBottom(using: proxy)
                }
            }
            .onChange(of: conversation.stage) { _, _ in
                guard session.currentRole == .vendor else { return }
                Task {
                    await inboxStore.refreshDateConflicts(in: conversationID)
                }
            }
        }
        .navigationTitle(conversation.counterpartName(for: session.currentRole))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if conversation.stage.isCancellable,
               !(session.currentRole == .vendor && conversation.stage == .requested) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        cancellationReason = ""
                        isPresentingCancellationPrompt = true
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingPaymentSheet) {
            VendorPaymentRequestSheet(
                vendorName: vendor?.businessName ?? conversation.vendorName,
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
        .hapticFeedback(.impact(weight: .medium), trigger: sendHapticTrigger)
        .hapticFeedback(.warning, trigger: isPresentingDeclinePrompt) { _, new in new }
        .hapticFeedback(.warning, trigger: isPresentingCancellationPrompt) { _, new in new }
        .alert("Decline request", isPresented: $isPresentingDeclinePrompt) {
            TextField("Optional reason", text: $declineReason)

            Button("Keep request", role: .cancel) {
                declineReason = ""
            }

            Button("Decline", role: .destructive) {
                Task {
                    await inboxStore.declineBooking(
                        in: conversationID,
                        reason: declineReason.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    )
                }
                declineReason = ""
            }
        } message: {
            Text("This will decline the booking request. The vendor will be notified.")
        }
        .alert("Cancel booking", isPresented: $isPresentingCancellationPrompt) {
            TextField("Optional reason", text: $cancellationReason)

            Button("Keep booking", role: .cancel) {
                cancellationReason = ""
            }

            Button("Cancel booking", role: .destructive) {
                inboxStore.cancelBooking(
                    in: conversationID,
                    reason: cancellationReason.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
                cancellationReason = ""
            }
        } message: {
            if conversation.stage != .paid {
                Text("No approval needed — no payment has been made.")
            } else if let vendorProfile = inboxStore.vendorProfile(id: conversation.vendorID),
                      let days = vendorProfile.cancellationDeadlineDays,
                      let eventDate = conversation.bookingEventDate,
                      eventDate.timeIntervalSinceNow <= Double(days) * 86_400 {
                Text("This vendor's cancellation policy requires their approval for cancellations within \(days) days of the event. Your request will be sent to the vendor.")
            } else {
                Text("This will cancel the booking. Your conversation history will still be available.")
            }
        }
        .modifier(CancellationRequestAlerts(
            conversationID: conversationID,
            conversation: conversation,
            role: session.currentRole,
            isPresentingApproval: $isPresentingCancellationApproval,
            isPresentingDecline: $isPresentingCancellationDeclinePrompt,
            isPresentingForceCancel: $isPresentingForceCancelPrompt,
            declineReason: $cancellationDeclineReason
        ))
        .alert(
            "Payment failed",
            isPresented: confirmPaymentErrorBinding
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(inboxStore.confirmPaymentError ?? "Something went wrong. Please try again.")
        }
        .modifier(BookingActionErrorAlert(inboxStore: inboxStore))
    }

    private var confirmPaymentErrorBinding: Binding<Bool> {
        Binding(
            get: { inboxStore.confirmPaymentError != nil },
            set: { if !$0 { inboxStore.confirmPaymentError = nil } }
        )
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }
}

private struct CancellationRequestAlerts: ViewModifier {
    let conversationID: UUID
    let conversation: ConversationThread
    let role: UserRole
    @Binding var isPresentingApproval: Bool
    @Binding var isPresentingDecline: Bool
    @Binding var isPresentingForceCancel: Bool
    @Binding var declineReason: String

    @Environment(InboxStore.self) private var inboxStore

    private var requesterLabel: String {
        guard let requestedByRole = conversation.cancellationRequestedByRole else { return "the other party" }
        return requestedByRole == .host ? "the host" : "the vendor"
    }

    private var counterpartLabel: String {
        role == .host ? "The vendor" : "The host"
    }

    func body(content: Content) -> some View {
        content
            .alert("Approve cancellation", isPresented: $isPresentingApproval) {
                Button("Keep booking", role: .cancel) { }
                Button("Approve", role: .destructive) {
                    Task {
                        await inboxStore.approveCancellationRequest(in: conversationID)
                    }
                }
            } message: {
                Text("This will cancel the booking as requested by \(requesterLabel).")
            }
            .alert("Decline cancellation request", isPresented: $isPresentingDecline) {
                TextField("Optional reason", text: $declineReason)
                Button("Cancel", role: .cancel) {
                    declineReason = ""
                }
                Button("Decline request") {
                    Task {
                        await inboxStore.declineCancellationRequest(
                            in: conversationID,
                            reason: declineReason.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        )
                    }
                    declineReason = ""
                }
            } message: {
                Text("The booking will revert to its previous state. \(counterpartLabel) will be notified.")
            }
            .alert("Cancel anyway", isPresented: $isPresentingForceCancel) {
                Button("Keep booking", role: .cancel) { }
                Button("Cancel booking", role: .destructive) {
                    inboxStore.forceCancelBooking(in: conversationID, reason: nil)
                }
            } message: {
                Text("This will cancel the booking despite the decline. The other party will be notified.")
            }
    }
}

private struct BookingActionErrorAlert: ViewModifier {
    @Bindable var inboxStore: InboxStore

    func body(content: Content) -> some View {
        content.alert(
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
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
