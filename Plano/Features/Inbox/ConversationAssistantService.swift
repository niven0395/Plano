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
            summary = "This conversation is open. Send a booking request when you're ready to move forward."
            nextAction = "Send a booking request once the event details are clear."
        case .requested:
            summary = "A booking request is live. The latest context is: \(latestCounterpartMessage)"
            nextAction = role == .vendor
                ? "Review the request, then accept or decline."
                : "Your request is with the vendor now. They'll respond here when ready."
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
            nextAction = "Use this conversation for timeline updates, guest-count changes, and coordination."
        case .declined:
            summary = "The request was declined, but the conversation history still holds the full brief and any feedback."
            nextAction = "You can continue the conversation or look for another vendor."
        case .cancellationRequested:
            summary = "The host has requested to cancel this booking. The vendor needs to approve or decline the request."
            nextAction = role == .vendor
                ? "Review the cancellation request and approve or decline it."
                : "Your cancellation request is pending vendor approval."
        case .cancelled:
            summary = "This booking was cancelled. The conversation history is still available if you need it."
            nextAction = "Share any final details here if needed."
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
            suggestedReply = "Payment is done. I'll share any timing or event updates here."
        case (.host, .declined):
            suggestedReply = "Thanks for letting me know. I'll take a look at next steps."
        case (.host, .cancellationRequested):
            suggestedReply = "I've submitted the cancellation request. I'll wait for the vendor's response."
        case (.host, .cancelled):
            suggestedReply = "Understood. I'll share any final details here."
        case (.host, .completed):
            suggestedReply = "Thanks again. I'll keep any final wrap-up or delivery details in this thread."
        case (.vendor, .active):
            suggestedReply = "Once you send a booking request, I'll review the details and get back to you."
        case (.vendor, .requested):
            suggestedReply = "I have the request details now. I'm reviewing and will reply here with the cleanest next step."
        case (.vendor, .accepted):
            suggestedReply = "I've accepted the booking. I'll send a payment request once the details are finalized."
        case (.vendor, .paymentRequested):
            suggestedReply = "Payment request is sent. As soon as it clears, I'll treat this as confirmed work."
        case (.vendor, .paid):
            suggestedReply = "Perfect, the booking is confirmed. I'll share any updates and event details here."
        case (.vendor, .declined):
            suggestedReply = "Understood. If anything changes, feel free to reach out here."
        case (.vendor, .cancellationRequested):
            suggestedReply = "I see the cancellation request. I'll review it and respond shortly."
        case (.vendor, .cancelled):
            suggestedReply = "Noted. I'll share any final details here if needed."
        case (.vendor, .completed):
            suggestedReply = "The work is complete on my side. I'll share any final details or deliverables here."
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
            detail = "The conversation is open. Send a booking request when you're ready."
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
