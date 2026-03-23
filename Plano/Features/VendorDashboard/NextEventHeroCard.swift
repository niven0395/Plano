import SwiftUI

struct NextEventHeroCard: View {
    let workspace: VendorEventWorkspaceSnapshot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AppSurface(style: .highlighted) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(countdownDotColor)
                            .frame(width: 10, height: 10)

                        Text(workspace.countdownLabel)
                            .font(.system(size: 26, weight: .medium))
                            .tracking(-0.8)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(workspace.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("\(workspace.serviceLine) · \(workspace.hostName)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    HStack(spacing: 14) {
                        Label(workspace.dateLabel, systemImage: "calendar")
                        Label(workspace.venue, systemImage: "mappin.and.ellipse")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)

                    StatusBadge(title: workspace.paymentLabel, tone: paymentTone)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next event: \(workspace.title), \(workspace.countdownLabel), \(workspace.dateLabel)")
        .accessibilityHint("Opens the event workspace")
    }

    private var countdownDotColor: Color {
        if workspace.countdownLabel == "Today" || workspace.countdownLabel == "Tomorrow" {
            return AppTheme.toneColor(.gold)
        }
        return AppTheme.toneColor(.sage)
    }

    private var paymentTone: AccentTone {
        workspace.stage == .paymentRequested ? .gold : .sage
    }
}

#Preview("Next Event") {
    NextEventHeroCard(
        workspace: VendorEventWorkspaceSnapshot(
            id: UUID(),
            title: "Rivera Engagement Party",
            hostName: "Mariana Rivera",
            serviceLine: "DJ & Sound",
            dateLabel: "Saturday, April 12",
            venue: "The Broadview Hotel",
            guestCountLabel: "45 guests",
            countdownLabel: "29 days out",
            stage: .paid,
            paymentLabel: "$800 paid",
            balanceLabel: "$1,600 remaining",
            metrics: [],
            reminders: [],
            conversationID: UUID(),
            note: "Confirmed in the shared conversation thread.",
            isLiveActivityActive: false,
            usesPreviewLiveActivity: false,
            coBookedVendors: []
        ),
        onTap: {}
    )
    .padding(AppTheme.screenPadding)
    .background(AppBackdrop())
}

#Preview("Tomorrow") {
    NextEventHeroCard(
        workspace: VendorEventWorkspaceSnapshot(
            id: UUID(),
            title: "Chen Birthday Celebration",
            hostName: "David Chen",
            serviceLine: "Photography",
            dateLabel: "Sunday, March 15",
            venue: "Casa Loma",
            guestCountLabel: "80 guests",
            countdownLabel: "Tomorrow",
            stage: .paid,
            paymentLabel: "$500 paid",
            balanceLabel: "$1,000 remaining",
            metrics: [],
            reminders: [],
            conversationID: UUID(),
            note: "Final shot list confirmed.",
            isLiveActivityActive: false,
            usesPreviewLiveActivity: false,
            coBookedVendors: []
        ),
        onTap: {}
    )
    .padding(AppTheme.screenPadding)
    .background(AppBackdrop())
}
