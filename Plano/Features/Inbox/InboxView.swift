import SwiftUI

struct InboxView: View {
    let store: InboxStore
    @Environment(SessionStore.self) private var session
    @Environment(RealtimeManager.self) private var realtimeManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AppRouter.self) private var router

    private func filterCount(_ filter: InboxFilter, for role: UserRole) -> Int {
        let scoped = store.scopedConversations(for: role)
        switch filter {
        case .all:
            return scoped
                .filter { !store.isArchived($0.id, for: role) }
                .filter { !($0.stage.isTerminal && $0.unreadCount(for: role) == 0) }
                .count
        case .unread:
            return scoped
                .filter { !store.isArchived($0.id, for: role) && $0.unreadCount(for: role) > 0 }
                .count
        case .archived:
            return scoped.filter { store.isArchived($0.id, for: role) }.count
        }
    }

    var body: some View {
        @Bindable var store = store
        let role = session.currentRole
        let visibleConversations = store.visibleConversations(for: role)

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                ConnectionStatusBanner(
                    connectionState: realtimeManager.connectionState,
                    isNetworkConnected: networkMonitor.isConnected,
                    hasEverConnected: realtimeManager.hasEverConnected
                )

                SectionHeader(
                    title: "Inbox",
                    subtitle: inboxSubtitle(for: role)
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(InboxFilter.allCases) { filter in
                            Button {
                                store.filter = filter
                            } label: {
                                InboxFilterChip(
                                    title: filter.title,
                                    count: filterCount(filter, for: role),
                                    isSelected: store.filter == filter
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .hapticFeedback(.selection, trigger: store.filter)
            }
            .padding(AppTheme.screenPadding)

            if store.loadingState == .loading, visibleConversations.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            ConversationCardSkeleton()
                        }
                    }
                    .padding(AppTheme.screenPadding)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            } else if visibleConversations.isEmpty {
                ScrollView {
                    Group {
                        if store.conversations.isEmpty {
                            InboxEmptyStateWithCTA(
                                onBrowse: {
                                    router.resetDiscoveryPaths()
                                    router.selectedTab = .home
                                }
                            )
                        } else {
                            EmptyStateCard(
                                symbolName: "tray",
                                title: emptyFilterTitle(store.filter),
                                message: emptyFilterMessage(store.filter)
                            )
                        }
                    }
                    .padding(AppTheme.screenPadding)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            } else {
                List {
                    ForEach(Array(visibleConversations.enumerated()), id: \.element.id) { index, conversation in
                        ZStack {
                            NavigationLink(value: InboxRoute.conversation(conversation.id)) {
                                EmptyView()
                            }
                            .opacity(0)

                            ConversationCard(conversation: conversation)
                        }
                        .staggeredAppear(index: index)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: 6,
                            leading: AppTheme.screenPadding,
                            bottom: 6,
                            trailing: AppTheme.screenPadding
                        ))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if store.filter == .archived {
                                Button {
                                    store.unarchiveConversation(conversation.id, for: session.currentRole)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Label("Unarchive", systemImage: "tray.and.arrow.up")
                                }
                                .tint(.blue)
                            } else {
                                Button {
                                    store.archiveConversation(conversation.id, for: session.currentRole)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                        .contextMenu {
                            if store.filter == .archived {
                                Button {
                                    store.unarchiveConversation(conversation.id, for: session.currentRole)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Label("Unarchive", systemImage: "tray.and.arrow.up")
                                }
                            } else {
                                Button {
                                    store.archiveConversation(conversation.id, for: session.currentRole)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .animation(.easeOut(duration: 0.3), value: visibleConversations.map(\.id))
            }
        }
        .background(AppBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: session.currentRole) {
            await store.loadConversationsIfNeeded(for: session.currentRole)
        }
    }

    private func inboxSubtitle(for role: UserRole) -> String {
        let unread = store.unreadCount(for: role)
        if unread == 0 { return "All threads are up to date." }
        return "\(unread) unread conversation\(unread == 1 ? "" : "s")."
    }

    private func emptyFilterTitle(_ filter: InboxFilter) -> String {
        switch filter {
        case .unread:
            return "No unread threads"
        case .archived:
            return "No archived threads"
        case .all:
            return "Nothing in this view"
        }
    }

    private func emptyFilterMessage(_ filter: InboxFilter) -> String {
        switch filter {
        case .unread:
            return "You're caught up. Switch to All to see every thread."
        case .archived:
            return "Archived threads will appear here. Swipe a row to archive it."
        case .all:
            return "Switch to Unread or Archived to see other views."
        }
    }
}

// MARK: - Filter chip with count

private struct InboxFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? AppTheme.Palette.accent : AppTheme.Palette.textSecondary)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 18)
                    .background(
                        isSelected
                            ? AnyShapeStyle(AppTheme.Palette.elevatedSurface)
                            : AnyShapeStyle(AppTheme.Palette.chipFill),
                        in: Capsule()
                    )
            }
        }
        .foregroundStyle(isSelected ? AppTheme.Palette.elevatedSurface : AppTheme.Palette.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isSelected
                ? AnyShapeStyle(AppTheme.Palette.accent)
                : AnyShapeStyle(AppTheme.Palette.chipFill),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    isSelected ? AppTheme.Palette.accent : AppTheme.Palette.border,
                    lineWidth: 1
                )
        }
        .animation(AppAnimation.feedback, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(count > 0 ? "\(title), \(count)" : title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Empty state with browse CTA

private struct InboxEmptyStateWithCTA: View {
    let onBrowse: () -> Void

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Palette.elevatedSurface)
                        .frame(width: 52, height: 52)
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                        .symbolEffect(.pulse.byLayer)
                }

                Text("Start a conversation")
                    .font(.system(size: 24, weight: .regular))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Your messages with vendors will live here. Browse vendors and tap Message to begin.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Button(action: onBrowse) {
                    Label("Browse vendors", systemImage: "magnifyingglass")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.top, 4)
            }
        }
    }
}

private struct ConversationCard: View {
    let conversation: ConversationSummary

    private var isUnread: Bool {
        conversation.unreadCount > 0
    }

    /// "Active" is the resting default; showing it adds noise. Only surface
    /// meaningful booking stages (requested, accepted, payment, cancellation,
    /// declined, cancelled, completed).
    private var showsStageBadge: Bool {
        conversation.stage != .active
    }

    var body: some View {
        HStack(spacing: 0) {
            // Leading accent stripe for unread rows — primary at-a-glance affordance.
            Rectangle()
                .fill(isUnread ? AppTheme.toneColor(conversation.stage.tone) : Color.clear)
                .frame(width: 3)
                .accessibilityHidden(true)

            AppSurface(compact: true) {
                HStack(alignment: .center, spacing: 12) {
                    avatar

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(conversation.counterpartName)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Text(conversation.timeLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                                .layoutPriority(1)
                        }

                        HStack(alignment: .center, spacing: 8) {
                            Text(conversation.preview)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            if showsStageBadge {
                                Text(conversation.stage.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.toneColor(conversation.stage.tone))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.toneBackground(conversation.stage.tone), in: Capsule())
                                    .layoutPriority(1)
                            } else if isUnread {
                                Text("\(conversation.unreadCount)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.Palette.accentForeground)
                                    .frame(minWidth: 20, minHeight: 20)
                                    .padding(.horizontal, 6)
                                    .background(AppTheme.Palette.accent, in: Capsule())
                                    .transition(.scale.combined(with: .opacity))
                                    .accessibilityLabel("\(conversation.unreadCount) unread")
                                    .layoutPriority(1)
                            }
                        }
                    }
                }
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.toneBackground(.sand))
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .stroke(AppTheme.Palette.border, lineWidth: 1)
                }

            Text(initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.toneColor(.sand))
        }
        .accessibilityHidden(true)
    }

    private var initials: String {
        conversation.counterpartName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }
}

private struct ConversationCardSkeleton: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 3)

            AppSurface(compact: true) {
                HStack(alignment: .top, spacing: 12) {
                    SkeletonCircle(size: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            SkeletonLine.medium
                            Spacer()
                            SkeletonLine.short
                        }

                        SkeletonLine.long
                            .frame(height: 12)

                        HStack {
                            SkeletonLine(width: 80, height: 22)
                            Spacer()
                            SkeletonLine(width: 22, height: 22)
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }
}
