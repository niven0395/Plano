import SwiftUI

struct InboxView: View {
    let store: InboxStore
    @Environment(SessionStore.self) private var session
    @Environment(RealtimeManager.self) private var realtimeManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    var body: some View {
        @Bindable var store = store
        let visibleConversations = store.visibleConversations(for: session.currentRole)

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                ConnectionStatusBanner(
                    connectionState: realtimeManager.connectionState,
                    isNetworkConnected: networkMonitor.isConnected,
                    hasEverConnected: realtimeManager.hasEverConnected
                )
                SectionHeader(
                    title: "Inbox",
                    subtitle: store.unreadCount(for: session.currentRole) == 0
                        ? "All threads are up to date."
                        : "\(store.unreadCount(for: session.currentRole)) unread conversations"
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(InboxFilter.allCases) { filter in
                            Button {
                                store.filter = filter
                            } label: {
                                FilterChip(title: filter.title, isSelected: store.filter == filter)
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
                            EmptyStateCard(
                                symbolName: "bubble.left.and.bubble.right",
                                title: "Start a conversation",
                                message: "Browse vendors and tap Message to begin."
                            )
                        } else {
                            EmptyStateCard(
                                symbolName: "bubble.left.and.bubble.right",
                                title: "Nothing in this inbox view",
                                message: "Switch the filter to inspect unread or archived threads."
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
                                Button(role: .destructive) {
                                    store.archiveConversation(conversation.id, for: session.currentRole)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } label: {
                                    Label(
                                        conversation.stage == .active ? "Delete" : "Archive",
                                        systemImage: conversation.stage == .active ? "trash" : "archivebox"
                                    )
                                }
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
                                Button(role: .destructive) {
                                    store.archiveConversation(conversation.id, for: session.currentRole)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } label: {
                                    Label(
                                        conversation.stage == .active ? "Delete" : "Archive",
                                        systemImage: conversation.stage == .active ? "trash" : "archivebox"
                                    )
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
}

private struct ConversationCard: View {
    let conversation: ConversationSummary

    var body: some View {
        AppSurface(compact: true) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Palette.glassHighlight)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(AppTheme.Palette.border, lineWidth: 1)
                        }

                    Text(initials)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(conversation.stage.tone))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conversation.counterpartName)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(conversation.timeLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)

                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.Palette.accentForeground)
                                .frame(width: 22, height: 22)
                                .background(AppTheme.Palette.accent, in: Circle())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text(conversation.preview)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .lineLimit(2)
                }
            }
        }
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
        AppSurface(compact: true) {
            HStack(alignment: .top, spacing: 12) {
                SkeletonCircle(size: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        SkeletonLine.medium
                        Spacer()
                        SkeletonLine.short
                    }

                    SkeletonLine(width: 120, height: 10)

                    SkeletonLine.long
                }
            }
        }
    }
}
