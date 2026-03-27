import SwiftUI

struct RequestsView: View {
    let store: RequestsStore

    @Environment(AppRouter.self) private var router
    @Environment(SearchStore.self) private var searchStore

    @State private var isPresentingCreator = false
    @State private var isPresentingEventSwitcher = false
    @State private var isConfirmingEventDelete = false
    @State private var isDeletingEvent = false
    @State private var eventDeletionError: String?
    @State private var selectedVendor: RequestsStore.VendorItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if store.hasEvents {
                    if store.hasUngroupedBookings {
                        UngroupedVendorsSection(
                            items: store.ungroupedItems,
                            events: store.events,
                            onOpenChat: { router.openConversation($0) },
                            onSelectVendor: { item in
                                selectedVendor = RequestsStore.VendorItem(
                                    id: item.id,
                                    vendorID: item.vendorID,
                                    vendorName: item.vendorName,
                                    category: item.vendorCategory,
                                    stage: item.stage,
                                    priceLabel: item.amountLabel,
                                    conversationID: item.id
                                )
                            },
                            onLinkToEvent: { conversationID, eventID in
                                Task { await store.linkToEvent(conversationID: conversationID, eventID: eventID) }
                            }
                        )
                    }
                    eventContent
                } else if store.hasUngroupedBookings {
                    UngroupedVendorsSection(
                        items: store.ungroupedItems,
                        events: [],
                        onOpenChat: { router.openConversation($0) },
                        onSelectVendor: { item in
                            selectedVendor = RequestsStore.VendorItem(
                                id: item.id,
                                vendorID: item.vendorID,
                                vendorName: item.vendorName,
                                category: item.vendorCategory,
                                stage: item.stage,
                                priceLabel: item.amountLabel,
                                conversationID: item.id
                            )
                        },
                        onLinkToEvent: { _, _ in }
                    )

                    if store.shouldShowEventPrompt {
                        EventEncouragementCard(
                            vendorCount: store.ungroupedConversations.count,
                            onCreate: { isPresentingCreator = true }
                        )
                    }
                } else {
                    emptyStateContent
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Planning")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("New Event", systemImage: "plus") {
                        isPresentingCreator = true
                    }

                    if store.hasEvents {
                        Divider()

                        Button(
                            store.activeEvent.eventStage == .cancelled ? "Remove Event" : "Delete Event",
                            systemImage: store.activeEvent.eventStage == .cancelled ? "xmark.circle" : "trash",
                            role: .destructive
                        ) {
                            isConfirmingEventDelete = true
                        }
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isPresentingCreator) {
            EventCreationSheet()
        }
        .sheet(isPresented: $isPresentingEventSwitcher) {
            RequestEventSwitcherSheet(
                events: store.events,
                selectedEventID: store.activeEvent.id,
                onSelect: { store.selectEvent($0) }
            )
        }
        .confirmationDialog(
            store.activeEvent.eventStage == .cancelled ? "Remove event" : "Delete event",
            isPresented: $isConfirmingEventDelete,
            titleVisibility: .visible
        ) {
            Button(store.activeEvent.eventStage == .cancelled ? "Remove event" : "Delete event", role: .destructive) {
                Task {
                    isDeletingEvent = true
                    let result = await store.deleteActiveEvent()
                    isDeletingEvent = false

                    if let result {
                        router.showEventTabRoot()
                    } else {
                        eventDeletionError = "Could not delete this event. Check your connection and try again."
                    }
                }
            }
        } message: {
            if store.activeEvent.eventStage == .cancelled && store.activeBookingCount == 0 {
                Text("This cancelled event will be permanently removed along with its planning data.")
            } else {
                let count = store.activeBookingCount
                if count > 0 {
                    Text("This will cancel \(count) active booking\(count == 1 ? "" : "s") and notify the affected vendors. This action cannot be undone.")
                } else {
                    Text("This event and all associated data will be permanently removed. This action cannot be undone.")
                }
            }
        }
        .alert("Unable to delete", isPresented: .init(
            get: { eventDeletionError != nil },
            set: { if !$0 { eventDeletionError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(eventDeletionError ?? "")
        }
        .alert(
            "Payment failed",
            isPresented: Binding(
                get: { store.inboxStore.confirmPaymentError != nil },
                set: { if !$0 { store.inboxStore.confirmPaymentError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(store.inboxStore.confirmPaymentError ?? "Something went wrong. Please try again.")
        }
        .sheet(item: $selectedVendor) { vendor in
            VendorBookingDetailSheet(
                vendor: vendor,
                onOpenChat: { router.openConversation($0) },
                onViewProfile: { router.openVendorProfile($0) },
                onConfirmPayment: { await store.inboxStore.confirmPayment(in: $0) }
            )
        }
    }

    // MARK: - Event Content

    @ViewBuilder
    private var eventContent: some View {
        EventHeaderCard(
            event: store.activeEvent,
            daysUntil: store.daysUntilEvent,
            onRemove: store.activeEvent.eventStage == .cancelled
                ? { isConfirmingEventDelete = true } : nil
        )

        if store.events.count > 1 {
            Button {
                isPresentingEventSwitcher = true
            } label: {
                Label("Switch event", systemImage: "arrow.triangle.swap")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.accent)
            }
        }

        ForEach(store.categoryGroups) { group in
            CategoryVendorSection(group: group, selectedVendor: $selectedVendor)
        }
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
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

}

// MARK: - Event Header Card

private struct EventHeaderCard: View {
    let event: PartyEvent
    let daysUntil: Int
    var onRemove: (() -> Void)?

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.system(size: 28, weight: .regular))
                            .tracking(-0.8)
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
                    Label(event.venue, systemImage: "mappin.and.ellipse")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
                .lineLimit(1)

                HStack(spacing: 14) {
                    Label(event.city, systemImage: "location.fill")
                    Label(event.guestCountLabel, systemImage: "person.2.fill")
                    Label(event.budgetLabel, systemImage: "creditcard.fill")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
                .lineLimit(1)

                if daysUntil > 0 {
                    Text("\(daysUntil) days away")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(daysUntil <= 14 ? .gold : .sage))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            AppTheme.toneBackground(daysUntil <= 14 ? .gold : .sage),
                            in: Capsule()
                        )
                } else if event.eventStage == .cancelled, let onRemove {
                    Button("Remove event", systemImage: "xmark.circle", action: onRemove)
                        .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}

// MARK: - Category Vendor Section

private struct CategoryVendorSection: View {
    let group: RequestsStore.CategoryGroup
    @Binding var selectedVendor: RequestsStore.VendorItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: group.category.symbolName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.toneColor(group.category.accentTone))

                Text(group.category.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
            }

            LazyVStack(spacing: 12) {
                ForEach(group.vendors) { vendor in
                    Button {
                        selectedVendor = vendor
                    } label: {
                        CategoryVendorCard(vendor: vendor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CategoryVendorCard: View {
    let vendor: RequestsStore.VendorItem

    var body: some View {
        AppSurface {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.vendorName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(vendor.priceLabel)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }

                Spacer()

                StatusBadge(title: vendor.stage.title, tone: vendor.stage.tone)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
            }
        }
    }
}

// MARK: - Ungrouped Vendors Section

private struct UngroupedVendorsSection: View {
    let items: [RequestsStore.RequestItem]
    let events: [PartyEvent]
    let onOpenChat: (UUID) -> Void
    let onSelectVendor: (RequestsStore.RequestItem) -> Void
    let onLinkToEvent: (UUID, UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Your vendors",
                subtitle: "\(items.count) vendor\(items.count == 1 ? "" : "s") not yet linked to an event."
            )

            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    UngroupedVendorCard(
                        item: item,
                        events: events,
                        onOpenChat: onOpenChat,
                        onSelectVendor: onSelectVendor,
                        onLinkToEvent: onLinkToEvent
                    )
                }
            }
        }
    }
}

private struct UngroupedVendorCard: View {
    let item: RequestsStore.RequestItem
    let events: [PartyEvent]
    let onOpenChat: (UUID) -> Void
    let onSelectVendor: (RequestsStore.RequestItem) -> Void
    let onLinkToEvent: (UUID, UUID) -> Void

    var body: some View {
        Button {
            onSelectVendor(item)
        } label: {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
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

                    HStack(spacing: 12) {
                        if !item.amountLabel.isEmpty {
                            Text(item.amountLabel)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)
                    }
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
        }
    }
}

private struct EventEncouragementCard: View {
    let vendorCount: Int
    let onCreate: () -> Void

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                Text("Organize your vendors")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("You have \(vendorCount) vendors booked independently. Create an event to group them, track progress, and manage everything in one place.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Create event", systemImage: "plus") {
                    onCreate()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }
}

// MARK: - Event Switcher

private struct RequestEventSwitcherSheet: View {
    let events: [PartyEvent]
    let selectedEventID: UUID
    let onSelect: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        title: "Switch event",
                        subtitle: "Requests and saved-vendor context update to the selected event immediately."
                    )

                    LazyVStack(spacing: 16) {
                        ForEach(events) { event in
                            Button {
                                onSelect(event.id)
                                dismiss()
                            } label: {
                                RequestEventRow(event: event, isSelected: event.id == selectedEventID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(AppTheme.screenPadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AppBackdrop())
            .navigationTitle("Selected Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct RequestEventRow: View {
    let event: PartyEvent
    let isSelected: Bool

    var body: some View {
        AppSurface(style: isSelected ? .highlighted : .regular) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(event.type.title)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer()

                    StatusBadge(
                        title: isSelected ? "Selected" : event.stage.title,
                        tone: isSelected ? .blue : event.stage.tone
                    )
                }

                HStack(spacing: 14) {
                    Label(event.formattedDate, systemImage: "calendar")
                    Label(event.venue, systemImage: "mappin.and.ellipse")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

                Text("\(event.guestCountLabel) • \(event.budgetLabel)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                ProgressView(value: event.progress)
                    .tint(AppTheme.Palette.accent)
            }
        }
        .opacity(event.eventStage == .cancelled && !isSelected ? 0.6 : 1)
    }
}
