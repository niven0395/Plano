import SwiftUI

struct EventListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(HostPlanningStore.self) private var planner
    @Environment(InboxStore.self) private var inboxStore
    @Environment(RequestsStore.self) private var requestsStore

    @State private var isPresentingCreator = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    SectionHeader(title: "Planning")
                    Spacer()
                    Button("New Event", systemImage: "plus") {
                        isPresentingCreator = true
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                }

                if planner.events.isEmpty && !requestsStore.hasUngroupedBookings {
                    emptyState
                } else {
                    eventCards

                    if requestsStore.hasUngroupedBookings {
                        ungroupedSection
                    }
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isPresentingCreator) {
            EventCreationSheet()
        }
    }

    // MARK: - Event Cards

    @ViewBuilder
    private var eventCards: some View {
        let sorted = planner.events.sorted { $0.date < $1.date }

        LazyVStack(spacing: 16) {
            ForEach(sorted) { event in
                Button {
                    router.selectedTab = .events
                    router.eventsPath = [.eventDetail(event.id)]
                } label: {
                    EventListCard(
                        event: event,
                        bookedCount: bookedCount(for: event),
                        totalCategories: totalCategories(for: event)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Ungrouped Section

    private var ungroupedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Your vendors",
                subtitle: "\(requestsStore.ungroupedConversations.count) vendor\(requestsStore.ungroupedConversations.count == 1 ? "" : "s") not yet linked to an event."
            )

            LazyVStack(spacing: 12) {
                ForEach(requestsStore.ungroupedItems) { item in
                    UngroupedVendorRow(
                        item: item,
                        events: planner.events,
                        onOpenChat: { router.openConversation($0) },
                        onLinkToEvent: { conversationID, eventID in
                            Task { await requestsStore.linkToEvent(conversationID: conversationID, eventID: eventID) }
                        },
                        onRemoveVendor: { inboxStore.archiveConversation($0, for: .host) }
                    )
                }
            }

            if requestsStore.shouldShowEventPrompt {
                AppSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Organize your vendors")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Create an event to group your vendors, track progress, and manage everything in one place.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Create event", systemImage: "plus") {
                            isPresentingCreator = true
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Plan your event")
                    .font(.system(size: 28, weight: .regular))
                    .tracking(-0.8)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Add the basics to tailor vendor search, pricing, and organize your booked vendors.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Button("Create event", systemImage: "plus") {
                    isPresentingCreator = true
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }

    // MARK: - Helpers

    private func bookedCount(for event: PartyEvent) -> Int {
        inboxStore.eventConversations(eventID: event.id)
            .filter { !$0.isHostCancelled && !inboxStore.isArchived($0.id, for: .host) }
            .count
    }

    private func totalCategories(for event: PartyEvent) -> Int {
        planner.categories(for: event).count
    }
}

// MARK: - Event List Card

private struct EventListCard: View {
    let event: PartyEvent
    let bookedCount: Int
    let totalCategories: Int

    private var daysUntil: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: event.date).day ?? 0)
    }

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.system(size: 24, weight: .regular))
                            .tracking(-0.6)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(event.type.title)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer()

                    StatusBadge(title: event.eventStage.title, tone: event.eventStage.tone)
                }

                HStack(spacing: 14) {
                    Label(event.formattedDate, systemImage: "calendar")
                    Label(event.city, systemImage: "location.fill")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
                .lineLimit(1)

                HStack(spacing: 14) {
                    if totalCategories > 0 {
                        Label(
                            "\(bookedCount) of \(totalCategories) vendors",
                            systemImage: "person.2.fill"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                    }

                    Spacer()

                    countdownPill
                }

                HStack {
                    Text("View event")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.accent)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
            }
        }
        .opacity(event.eventStage == .cancelled ? 0.6 : 1)
    }

    @ViewBuilder
    private var countdownPill: some View {
        if event.eventStage != .cancelled {
            let label = daysUntil == 0 ? "Today" : daysUntil == 1 ? "Tomorrow" : "\(daysUntil) days"

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
}

// MARK: - Ungrouped Vendor Row

private struct UngroupedVendorRow: View {
    let item: RequestsStore.RequestItem
    let events: [PartyEvent]
    let onOpenChat: (UUID) -> Void
    let onLinkToEvent: (UUID, UUID) -> Void
    var onRemoveVendor: ((UUID) -> Void)?

    var body: some View {
        Button {
            onOpenChat(item.id)
        } label: {
            AppSurface {
                HStack(spacing: 12) {
                    Image(systemName: item.vendorCategory.symbolName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.toneColor(item.vendorCategory.accentTone))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.vendorName)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(item.vendorCategory.singularTitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer()

                    StatusBadge(title: item.stage.title, tone: item.stage.tone)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open chat", systemImage: "bubble.left") {
                onOpenChat(item.id)
            }

            if !events.isEmpty {
                Menu("Add to event") {
                    ForEach(events) { event in
                        Button(event.title) {
                            onLinkToEvent(item.id, event.id)
                        }
                    }
                }
            }

            if item.stage.isTerminal, let onRemoveVendor {
                Button("Remove", systemImage: "trash", role: .destructive) {
                    onRemoveVendor(item.id)
                }
            }
        }
    }
}
