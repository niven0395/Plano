import SwiftUI

struct EventDetailView: View {
    let eventID: UUID

    @Environment(AppRouter.self) private var router
    @Environment(HostPlanningStore.self) private var planner
    @Environment(InboxStore.self) private var inboxStore
    @Environment(EventWorkspaceStore.self) private var workspaceStore

    @State private var selectedBookingVendor: RequestsStore.VendorItem?
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var deletionError: String?

    private var event: PartyEvent? {
        planner.event(id: eventID)
    }

    var body: some View {
        Group {
            if let event {
                eventContent(event)
            } else {
                EmptyStateCard(
                    symbolName: "calendar.badge.exclamationmark",
                    title: "Event unavailable",
                    message: "This event could not be loaded."
                )
                .padding(AppTheme.screenPadding)
                .background(AppBackdrop())
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func eventContent(_ event: PartyEvent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroCard(event)

                if let workspace = workspaceStore.hostWorkspace(for: eventID) {
                    metricsSection(workspace)
                }

                vendorTeamSection(event)

                deleteSection(event)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedBookingVendor) { vendor in
            VendorBookingDetailSheet(
                vendor: vendor,
                onOpenChat: { router.openConversation($0) },
                onViewProfile: { router.openVendorProfile($0) },
                onConfirmPayment: { await inboxStore.confirmPayment(in: $0) }
            )
        }
        .confirmationDialog(
            event.eventStage == .cancelled ? "Remove event" : "Delete event",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(event.eventStage == .cancelled ? "Remove event" : "Delete event", role: .destructive) {
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
            let threads = inboxStore.eventConversations(eventID: eventID)
            let activeCount = threads.filter { !$0.stage.isTerminal }.count
            if event.eventStage == .cancelled && activeCount == 0 {
                Text("This cancelled event will be permanently removed along with its planning data.")
            } else if activeCount > 0 {
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
    }

    // MARK: - Hero Card

    private func heroCard(_ event: PartyEvent) -> some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.system(size: 30, weight: .regular))
                            .tracking(-0.8)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(event.type.title)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer()

                    StatusBadge(title: event.eventStage.title, tone: event.eventStage.tone)
                }

                HStack(spacing: 12) {
                    Label(event.formattedDateWithTime, systemImage: "calendar")
                    Label(event.venue, systemImage: "mappin.and.ellipse")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
                .lineLimit(1)

                HStack(spacing: 14) {
                    Label(event.city, systemImage: "location.fill")
                    Label(event.guestCountLabel, systemImage: "person.2.fill")
                    Label(event.venueSetting.title, systemImage: "building.2")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
                .lineLimit(1)

                countdownPill(for: event)

                if !event.planningNote.isEmpty {
                    Text(event.planningNote)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Button("Browse vendors") {
                    router.selectedTab = .home
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func countdownPill(for event: PartyEvent) -> some View {
        let daysUntil = max(0, Calendar.current.dateComponents([.day], from: .now, to: event.date).day ?? 0)

        if daysUntil > 0 && event.eventStage != .cancelled {
            let label = daysUntil == 1 ? "Tomorrow" : "\(daysUntil) days away"

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.toneColor(daysUntil <= 14 ? .gold : .sage))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    AppTheme.toneBackground(daysUntil <= 14 ? .gold : .sage),
                    in: Capsule()
                )
        }
    }

    // MARK: - Metrics

    private func metricsSection(_ workspace: HostEventWorkspaceSnapshot) -> some View {
        let filtered = workspace.metrics.filter { $0.title == "Booked" || $0.title == "Paid" }
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ], spacing: 14) {
            ForEach(filtered) { metric in
                MetricTile(metric: metric)
            }
        }
    }

    // MARK: - Vendor Team

    private func vendorTeamSection(_ event: PartyEvent) -> some View {
        let threads = inboxStore.eventConversations(eventID: event.id)
            .filter { !$0.isHostCancelled && !inboxStore.isArchived($0.id, for: .host) }
            .sorted { lhs, rhs in
                if stageRank(lhs.stage) != stageRank(rhs.stage) {
                    return stageRank(lhs.stage) > stageRank(rhs.stage)
                }
                return lhs.lastActivityAt > rhs.lastActivityAt
            }

        return VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Vendor team",
                subtitle: "Vendors you've requested for this event."
            )

            if threads.isEmpty {
                EmptyStateCard(
                    symbolName: "person.2.slash",
                    title: "No vendors yet",
                    message: "Browse vendors to start building your team."
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(threads) { thread in
                        filledVendorCard(thread: thread, category: thread.vendorCategory)
                    }
                }
            }
        }
    }

    private func filledVendorCard(thread: ConversationThread, category: VendorCategory) -> some View {
        let vendor = planner.vendor(id: thread.vendorID) ?? inboxStore.vendorProfile(id: thread.vendorID)
        let priceLabel = thread.paymentRequest?.amountLabel ?? vendor?.planningPriceLabel ?? "Pricing on request"

        return Button {
            selectedBookingVendor = RequestsStore.VendorItem(
                id: thread.id,
                vendorID: thread.vendorID,
                vendorName: thread.vendorName,
                category: category,
                stage: thread.stage,
                priceLabel: priceLabel,
                eventDateLabel: thread.eventDateLabel,
                conversationID: thread.id
            )
        } label: {
            AppSurface {
                HStack(spacing: 12) {
                    Image(systemName: category.symbolName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.toneColor(category.accentTone))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(thread.vendorName)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(priceLabel)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)
                    }

                    Spacer()

                    StatusBadge(title: thread.stage.title, tone: thread.stage.tone)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if thread.stage.isTerminal {
                Button("Remove from plan", systemImage: "eye.slash", role: .destructive) {
                    inboxStore.archiveConversation(thread.id, for: .host)
                }
            }

            Button("Open chat", systemImage: "bubble.left") {
                router.openConversation(thread.id)
            }
        }
    }

    // MARK: - Delete Section

    private func deleteSection(_ event: PartyEvent) -> some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("Event management")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                let threads = inboxStore.eventConversations(eventID: eventID)
                let activeCount = threads.filter { !$0.stage.isTerminal }.count
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
                        Text(event.eventStage == .cancelled ? "Remove event" : "Delete event")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.toneColor(.coral))
                .disabled(isDeleting)
            }
        }
    }

    // MARK: - Helpers

    private func stageRank(_ stage: BookingStage) -> Int {
        switch stage {
        case .active: 0
        case .requested: 1
        case .cancellationRequested: 2
        case .accepted: 3
        case .paymentRequested: 4
        case .paid: 5
        case .declined, .cancelled: -1
        case .completed: 6
        }
    }
}

