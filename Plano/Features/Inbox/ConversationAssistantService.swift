import Foundation

struct ConversationAssistantBrief: Hashable {
    let title: String
    let summary: String
    let nextAction: String
    let suggestedReply: String
    let tone: AccentTone
}

enum ConversationAssistantService {

    // MARK: - Assistant brief

    static func assistantBrief(for thread: ConversationThread, role: UserRole) -> ConversationAssistantBrief? {
        guard thread.messages.count >= 3 else { return nil }

        let latestCounterpartMessage = thread.messages
            .reversed()
            .first { $0.sender.userRole == role.counterpart }?
            .previewText ?? thread.lastMessagePreview

        let summary: String
        let nextAction: String
        let suggestedReply: String

        switch thread.stage {
        case .active:
            summary = "This thread is open but still needs a booking request before it becomes an active booking."
            nextAction = "Send a booking request once the event details are clear."
        case .requested:
            summary = "A booking request is live. The latest context is: \(latestCounterpartMessage)"
            nextAction = role == .vendor
                ? "Review the request, then accept or decline."
                : "The request is now in the vendor queue. Keep follow-up messages focused so they can respond faster."
        case .accepted:
            summary = "The booking has been accepted. The latest context is: \(latestCounterpartMessage)"
            nextAction = role == .vendor
                ? "Request payment when ready to confirm the booking."
                : "The vendor accepted. Await their payment request or coordinate event details."
        case .paymentRequested:
            summary = "Payment has been requested and is waiting on host confirmation."
            nextAction = role == .host
                ? "Confirm the payment to lock the booking."
                : "Awaiting host payment confirmation."
        case .paid:
            summary = "Payment is confirmed and this vendor is locked in. The thread is now best used for event coordination."
            nextAction = "Keep timeline changes, guest-count updates, and delivery notes in this conversation."
        case .declined:
            summary = "The request was declined, but the conversation history still holds the full brief and any feedback."
            nextAction = "Decide whether to reopen scope here or move to another vendor."
        case .cancellationRequested:
            summary = "The host has requested to cancel this booking. The vendor needs to approve or decline the request."
            nextAction = role == .vendor
                ? "Review the cancellation request and approve or decline it."
                : "Your cancellation request is pending vendor approval."
        case .cancelled:
            summary = "This booking was cancelled. The thread now acts as an audit trail and any follow-up space."
            nextAction = "Keep only essential wrap-up details here so the closeout stays clear."
        case .completed:
            summary = "The work is complete. Keep final wrap-up notes and post-event coordination in the thread."
            nextAction = "Use the thread for any final deliverables, receipts, or recap messages."
        }

        switch (role, thread.stage) {
        case (.host, .active):
            suggestedReply = "I'm packaging the event details now so I can send a booking request."
        case (.host, .requested):
            suggestedReply = "Thanks -- the request has the full brief now, so I'll keep any follow-up notes here while you review it."
        case (.host, .accepted):
            suggestedReply = "Great, thanks for accepting. I'll keep the event details updated here."
        case (.host, .paymentRequested):
            suggestedReply = "Looks good. I'm confirming the payment now so we can move into final event coordination."
        case (.host, .paid):
            suggestedReply = "Payment is in. Let's keep all remaining timing and event notes in this thread so nothing slips."
        case (.host, .declined):
            suggestedReply = "Thanks for the clarity. I'll review whether we should adjust scope or close this out."
        case (.host, .cancellationRequested):
            suggestedReply = "I've submitted the cancellation request. I'll wait for the vendor's response."
        case (.host, .cancelled):
            suggestedReply = "Understood. I'll keep only the closeout details here so nothing gets lost."
        case (.host, .completed):
            suggestedReply = "Thanks again. I'll keep any final wrap-up or delivery details in this thread."
        case (.vendor, .active):
            suggestedReply = "Once the booking request lands, I can review the scope and move this into a clearer booking flow."
        case (.vendor, .requested):
            suggestedReply = "I have the request details now. I'm reviewing and will reply here with the cleanest next step."
        case (.vendor, .accepted):
            suggestedReply = "I've accepted the booking. I'll send a payment request once the details are finalized."
        case (.vendor, .paymentRequested):
            suggestedReply = "Payment request is sent. As soon as it clears, I'll treat this as confirmed work."
        case (.vendor, .paid):
            suggestedReply = "Perfect. The booking is confirmed, so I'll keep all timeline updates and operational notes in this thread."
        case (.vendor, .declined):
            suggestedReply = "Understood. If scope changes later, I can revisit it from the context already in this thread."
        case (.vendor, .cancellationRequested):
            suggestedReply = "I see the cancellation request. I'll review it and respond shortly."
        case (.vendor, .cancelled):
            suggestedReply = "I've logged the cancellation here. I'll keep any final operational notes brief and clear."
        case (.vendor, .completed):
            suggestedReply = "The work is complete on my side. I'll keep any remaining follow-up or handoff notes here."
        }

        return ConversationAssistantBrief(
            title: "Thread brief",
            summary: summary,
            nextAction: nextAction,
            suggestedReply: suggestedReply,
            tone: thread.stage.tone
        )
    }

    // MARK: - Updated summary

    static func updatedSummary(from summary: BookingRequestSummary, thread: ConversationThread, role: UserRole) -> BookingRequestSummary {
        let detail: String
        let amountLabel: String

        switch thread.stage {
        case .active:
            detail = "The conversation is open and ready for a structured request."
            amountLabel = summary.amountLabel
        case .requested:
            if role == .vendor {
                detail = "A booking request just came in. Review the brief before replying."
            } else {
                detail = "Your booking request is on the vendor's side now."
            }
            amountLabel = summary.amountLabel
        case .accepted:
            detail = "The booking has been accepted. The vendor can now request payment."
            amountLabel = summary.amountLabel
        case .paymentRequested:
            detail = "Payment has been requested. Awaiting host confirmation."
            amountLabel = thread.paymentRequest?.amountLabel ?? summary.amountLabel
        case .paid:
            detail = "Payment confirmed. This vendor is now confirmed for the event."
            amountLabel = thread.paymentRequest?.amountLabel ?? summary.amountLabel
        case .declined:
            detail = "The request was declined. You can keep the thread open for clarification or move on."
            amountLabel = summary.amountLabel
        case .cancellationRequested:
            detail = "A cancellation request is pending vendor approval."
            amountLabel = summary.amountLabel
        case .cancelled:
            detail = "The booking was cancelled. Keep any follow-up context in the thread."
            amountLabel = summary.amountLabel
        case .completed:
            detail = "This booking is complete. The thread stays available for wrap-up and records."
            amountLabel = thread.paymentRequest?.amountLabel ?? summary.amountLabel
        }

        return summary.updating(stage: thread.stage, detail: detail, amountLabel: amountLabel)
    }
}
