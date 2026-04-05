import SwiftUI

struct VendorDashboardView: View {
    let store: VendorDashboardStore
    @Environment(AppRouter.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @Environment(InboxStore.self) private var inboxStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VendorCalendarSection(
                    inboxStore: inboxStore
                )

                if !store.confirmedLeads.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(
                            title: "Confirmed bookings",
                            subtitle: "Your confirmed work at a glance."
                        )

                        Spacer(minLength: 12)

                        NavigationLink(value: DiscoveryRoute.vendorAllWork) {
                            HStack(spacing: 4) {
                                Text("See all")
                                Image(systemName: "chevron.right")
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    LazyVStack(spacing: 16) {
                        ForEach(store.confirmedLeads.prefix(2)) { lead in
                            NavigationLink(value: DiscoveryRoute.vendorLead(lead)) {
                                VendorConfirmedBookingCard(lead: lead)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                CompactRevenueCard(
                    todayTotal: store.todayTotalRevenueLabel,
                    isEmpty: store.todayRevenueSnapshot.isEmpty
                )

            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct VendorRequestsView: View {
    let store: VendorDashboardStore
    var showsNavigationBar = false

    @State private var selectedFilter: LeadFilter = .pending
    @Environment(InboxStore.self) private var inboxStore

    enum LeadFilter: String, CaseIterable, Identifiable {
        case pending = "Pending"
        case confirmed = "Confirmed"
        case history = "History"

        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "All leads")

                Picker("Filter", selection: $selectedFilter) {
                    ForEach(LeadFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedFilter {
                case .pending:
                    pendingContent
                case .confirmed:
                    confirmedContent
                case .history:
                    historyContent
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .toolbar(showsNavigationBar ? .automatic : .hidden, for: .navigationBar)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var pendingContent: some View {
        let leads = store.visibleLeadQueue
        let needingResponse = leads.filter(\.stage.requiresVendorAction)
        let waitingOnHost = leads.filter { !$0.stage.requiresVendorAction }

        if leads.isEmpty {
            EmptyStateCard(
                symbolName: "tray",
                title: "Queue is clear",
                message: "When a host reaches out or a quote needs follow-up, it will show up here immediately."
            )
        } else {
            if !needingResponse.isEmpty {
                leadSection(
                    title: "Needs your response",
                    subtitle: "\(needingResponse.count) leads waiting on a vendor decision or next step.",
                    requests: needingResponse
                )
            }

            if !waitingOnHost.isEmpty {
                leadSection(
                    title: "Waiting on host",
                    subtitle: "\(waitingOnHost.count) leads are with the host for approval or payment.",
                    requests: waitingOnHost
                )
            }
        }
    }

    @ViewBuilder
    private var confirmedContent: some View {
        let leads = store.confirmedLeads
            .map { inboxStore.updatedSummary(from: $0, for: .vendor) }

        if leads.isEmpty {
            EmptyStateCard(
                symbolName: "checkmark.seal",
                title: "No confirmed bookings",
                message: "Bookings with confirmed deposits will appear here."
            )
        } else {
            VendorLeadList(requests: leads)
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        let leads = store.historyLeads
            .map { inboxStore.updatedSummary(from: $0, for: .vendor) }

        if leads.isEmpty {
            EmptyStateCard(
                symbolName: "clock",
                title: "No past leads",
                message: "Completed, declined, and cancelled leads will appear here."
            )
        } else {
            VendorLeadList(requests: leads)
        }
    }

    private func leadSection(title: String, subtitle: String, requests: [BookingRequestSummary]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VendorLeadList(requests: requests)
        }
    }
}

private struct VendorLeadList: View {
    let requests: [BookingRequestSummary]

    var body: some View {
        AppSurface {
            VStack(spacing: 0) {
                ForEach(requests) { request in
                    if request.conversationID != nil {
                        NavigationLink(value: DiscoveryRoute.vendorLead(request)) {
                            VendorLeadRow(request: request, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the lead brief")
                    } else {
                        VendorLeadRow(request: request, showsChevron: false)
                    }

                    if request.id != requests.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct VendorLeadRow: View {
    let request: BookingRequestSummary
    let showsChevron: Bool

    @Environment(InboxStore.self) private var inboxStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(AppTheme.toneColor(request.stage.tone))
                .frame(width: 8, height: 8)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        counterpartLabel

                        Spacer(minLength: 12)

                        VendorLeadActionBadge(stage: request.stage)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        counterpartLabel
                        VendorLeadActionBadge(stage: request.stage)
                    }
                }

                Text("\(request.title) · \(request.dateLabel)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let conversationID = request.conversationID,
                   inboxStore.dateConflicts(in: conversationID).isEmpty == false {
                    Text("\(inboxStore.dateConflicts(in: conversationID).count) overlap warning\(inboxStore.dateConflicts(in: conversationID).count == 1 ? "" : "s")")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.gold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.toneColor(.gold).opacity(0.14), in: Capsule())
                }
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(request.counterpartName), \(request.title), \(request.dateLabel), \(request.stage.vendorActionLabel)")
    }

    private var counterpartLabel: some View {
        Text(request.counterpartName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct VendorLeadActionBadge: View {
    let stage: BookingStage

    var body: some View {
        Text(stage.vendorActionLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.toneColor(stage.tone))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.toneBackground(stage.tone), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.toneColor(stage.tone).opacity(0.18), lineWidth: 1)
            }
    }
}

private struct VendorConfirmedBookingCard: View {
    let lead: BookingRequestSummary

    var body: some View {
        AppSurface {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.toneColor(.sage))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lead.counterpartName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(lead.dateLabel)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Spacer()

                StatusBadge(title: lead.stage.title, tone: lead.stage.tone)
            }
        }
    }
}
