import SwiftUI

struct HostEventWorkspaceView: View {
    let eventID: UUID

    @Environment(EventWorkspaceStore.self) private var workspaceStore
    @Environment(HostPlanningStore.self) private var planner
    @Environment(AppRouter.self) private var router
    @Environment(InboxStore.self) private var inboxStore

    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var deletionError: String?

    var body: some View {
        if let workspace = workspaceStore.hostWorkspace(for: eventID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HostWorkspaceHeroCard(workspace: workspace)

                    WorkspaceMetricsGrid(metrics: workspace.metrics)

                    SectionHeader(
                        title: "Next steps",
                        subtitle: "Booking follow-through and event reminders stay centralized here."
                    )

                    if workspace.reminders.isEmpty {
                        EmptyStateCard(
                            symbolName: "checkmark.seal",
                            title: "Everything is aligned",
                            message: "Confirmed vendors and timing notes will keep surfacing here as the event gets closer."
                        )
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(workspace.reminders) { reminder in
                                EventWorkspaceReminderCard(reminder: reminder)
                            }
                        }
                    }

                    SectionHeader(
                        title: "Confirmed team",
                        subtitle: "Paid deposits, balances, and the next coordination step for each booked vendor."
                    )

                    if workspace.confirmedPartners.isEmpty {
                        EmptyStateCard(
                            symbolName: "person.2.slash",
                            title: "No confirmed vendors yet",
                            message: "Move a live quote through deposit to turn this into the event coordination surface."
                        )
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(workspace.confirmedPartners) { partner in
                                EventWorkspacePartnerCard(partner: partner)
                            }
                        }
                    }

                    if !workspace.activePartners.isEmpty {
                        SectionHeader(
                            title: "Booking in motion",
                            subtitle: "Threads that still need a quote review, deposit, or booking decision."
                        )

                        LazyVStack(spacing: 16) {
                            ForEach(workspace.activePartners) { partner in
                                EventWorkspacePartnerCard(partner: partner)
                            }
                        }
                    }

                    HostWorkspaceDeleteSection(
                        workspace: workspace,
                        isConfirmingDelete: $isConfirmingDelete,
                        isDeleting: $isDeleting
                    )
                }
                .padding(AppTheme.screenPadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AppBackdrop())
            .navigationTitle("Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Delete event",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete event", role: .destructive) {
                    Task {
                        isDeleting = true
                        let result = await planner.deleteEvent(eventID)
                        isDeleting = false

                        if let result {
                            router.showEventTabRoot()
                        } else {
                            deletionError = "Could not delete this event. Check your connection and try again."
                        }
                    }
                }
            } message: {
                let activeCount = workspace.confirmedPartners.count + workspace.activePartners.count
                if activeCount > 0 {
                    Text("This will cancel \(activeCount) active booking\(activeCount == 1 ? "" : "s") and notify the affected vendors. This action cannot be undone.")
                } else {
                    Text("This event and all associated data will be permanently removed. This action cannot be undone.")
                }
            }
            .alert("Unable to delete", isPresented: .init(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deletionError ?? "")
            }
            .alert(
                "Payment failed",
                isPresented: Binding(
                    get: { inboxStore.confirmPaymentError != nil },
                    set: { if !$0 { inboxStore.confirmPaymentError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(inboxStore.confirmPaymentError ?? "Something went wrong. Please try again.")
            }
        } else {
            workspaceUnavailable
        }
    }

    private var workspaceUnavailable: some View {
        ScrollView {
            VStack(spacing: 24) {
                EmptyStateCard(
                    symbolName: "calendar.badge.exclamationmark",
                    title: "This event workspace is not available",
                    message: "Return to the Requests tab and select another event to continue planning."
                )
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .background(AppBackdrop())
        .navigationTitle("Workspace")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VendorEventWorkspaceView: View {
    let workspaceID: UUID

    @Environment(EventWorkspaceStore.self) private var workspaceStore
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let workspace = workspaceStore.vendorWorkspace(for: workspaceID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VendorWorkspaceHeroCard(workspace: workspace)

                    WorkspaceMetricsGrid(metrics: workspace.metrics)

                    if !workspace.coBookedVendors.isEmpty {
                        SectionHeader(
                            title: "Event team",
                            subtitle: "Other confirmed vendors for this event"
                        )

                        LazyVStack(spacing: 12) {
                            ForEach(workspace.coBookedVendors) { coVendor in
                                CoBookedVendorCard(vendor: coVendor)
                            }
                        }
                    }

                    SectionHeader(
                        title: "Event reminders",
                        subtitle: "Keep deposits, timing notes, and day-of prep anchored to the event instead of scattered across tools."
                    )

                    LazyVStack(spacing: 16) {
                        ForEach(workspace.reminders) { reminder in
                            EventWorkspaceReminderCard(reminder: reminder)
                        }
                    }

                    SectionHeader(
                        title: "Coordination note",
                        subtitle: "The latest brief detail or quote context linked to this event."
                    )

                    AppSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(workspace.note)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)

                            HStack(spacing: 12) {
                                Label(workspace.paymentLabel, systemImage: "creditcard.fill")
                                Label(workspace.balanceLabel, systemImage: "banknote")
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)
                        }
                    }
                }
                .padding(AppTheme.screenPadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AppBackdrop())
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            workspaceUnavailable
        }
    }

    private var workspaceUnavailable: some View {
        ScrollView {
            VStack(spacing: 24) {
                EmptyStateCard(
                    symbolName: "calendar.badge.exclamationmark",
                    title: "This event is not available",
                    message: "Return to the Events tab to pick another upcoming event."
                )
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .background(AppBackdrop())
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HostWorkspaceHeroCard: View {
    let workspace: HostEventWorkspaceSnapshot

    @Environment(AppRouter.self) private var router

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    StatusBadge(
                        title: workspace.event.stage.title,
                        tone: workspace.event.stage.tone
                    )

                    Spacer()

                    Text(workspace.event.formattedDate)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(workspace.event.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(workspace.event.contextLine)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Label(workspace.countdownLabel, systemImage: "calendar.badge.clock")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)

                Text(workspace.event.planningNote)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                HStack(spacing: 12) {
                    Button("Browse vendors") {
                        router.selectedTab = .home
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button("Requests") {
                        router.showEventTabRoot()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}

private struct HostWorkspaceDeleteSection: View {
    let workspace: HostEventWorkspaceSnapshot
    @Binding var isConfirmingDelete: Bool
    @Binding var isDeleting: Bool

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("Danger zone")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                let activeCount = workspace.confirmedPartners.count + workspace.activePartners.count
                Text(activeCount > 0
                    ? "Deleting this event will cancel \(activeCount) active booking\(activeCount == 1 ? "" : "s") and notify each vendor."
                    : "Permanently remove this event and all associated planning data."
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Delete event")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.toneColor(.coral))
                .disabled(isDeleting)
            }
        }
    }
}

private struct VendorWorkspaceHeroCard: View {
    let workspace: VendorEventWorkspaceSnapshot

    @Environment(AppRouter.self) private var router

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    StatusBadge(
                        title: workspace.stage.title,
                        tone: workspace.stage.tone
                    )

                    Spacer()

                    Text(workspace.dateLabel)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(workspace.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("\(workspace.serviceLine) • \(workspace.hostName)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                HStack(spacing: 14) {
                    Label(workspace.venue, systemImage: "mappin.and.ellipse")
                    Label(workspace.guestCountLabel, systemImage: "person.3.fill")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

                Label(workspace.countdownLabel, systemImage: "calendar.badge.clock")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)

                if let conversationID = workspace.conversationID {
                    Button("Open thread") {
                        router.openConversation(conversationID)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
        }
    }
}

private struct WorkspaceMetricsGrid: View {
    let metrics: [MetricSummary]

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ], spacing: 14) {
            ForEach(metrics) { metric in
                MetricTile(metric: metric)
            }
        }
    }
}

struct VendorUpcomingWorkspaceCard: View {
    let workspace: VendorEventWorkspaceSnapshot

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workspace.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("\(workspace.serviceLine) • \(workspace.hostName)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer()

                    StatusBadge(title: workspace.stage.title, tone: workspace.stage.tone)
                }

                HStack(spacing: 14) {
                    Label(workspace.dateLabel, systemImage: "calendar")
                    Label(workspace.venue, systemImage: "mappin.and.ellipse")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

                Text(workspace.countdownLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
            }
        }
    }
}

private struct EventWorkspaceReminderCard: View {
    let reminder: EventWorkspaceReminder

    @Environment(AppRouter.self) private var router

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: reminder.symbolName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(reminder.tone))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(reminder.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(reminder.detail)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer()
                }

                if let conversationID = reminder.conversationID {
                    Button("Open thread") {
                        router.openConversation(conversationID)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}

private struct EventWorkspacePartnerCard: View {
    let partner: EventWorkspacePartner

    @Environment(AppRouter.self) private var router
    @Environment(InboxStore.self) private var inboxStore

    private var isConfirming: Bool {
        inboxStore.confirmingPaymentIDs.contains(partner.conversationID)
    }

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(partner.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(partner.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer()

                    StatusBadge(title: partner.stage.title, tone: partner.stage.tone)
                }

                Text(partner.note)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .lineLimit(3)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(partner.paymentLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Spacer()

                        Text(partner.balanceLabel)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)
                    }

                    Text(partner.nextStep)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                if partner.stage == .paymentRequested {
                    Button {
                        Task {
                            await inboxStore.confirmPayment(in: partner.conversationID)
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
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(isConfirming)
                }

                Button("Open thread") {
                    router.openConversation(partner.conversationID)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }
}

private struct CoBookedVendorCard: View {
    let vendor: CoBookedVendor

    var body: some View {
        AppSurface {
            HStack(spacing: 14) {
                Image(systemName: vendor.category.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.toneColor(.sage))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(vendor.category.singularTitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Spacer()

                StatusBadge(title: "Confirmed", tone: .sage)
            }
        }
    }
}
