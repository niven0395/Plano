import SwiftUI

struct VendorAllWorkView: View {
    @Environment(EventWorkspaceStore.self) private var workspaceStore
    @Environment(VendorDashboardStore.self) private var dashboardStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(
                    title: "All upcoming work",
                    subtitle: workspaceStore.vendorWorkspaces.isEmpty
                        ? "Confirmed work will appear here."
                        : "\(workspaceStore.vendorWorkspaces.count) confirmed events"
                )

                if workspaceStore.vendorWorkspaces.isEmpty {
                    EmptyStateCard(
                        symbolName: "calendar.badge.exclamationmark",
                        title: "No active events yet",
                        message: "Confirmed vendor work will surface here as bookings land."
                    )
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(workspaceStore.vendorWorkspaces) { workspace in
                            if let summary = dashboardStore.confirmedLead(forConversationID: workspace.conversationID ?? workspace.id) {
                                NavigationLink(value: DiscoveryRoute.vendorLead(summary)) {
                                    VendorUpcomingWorkspaceCard(workspace: workspace)
                                }
                                .buttonStyle(.plain)
                            } else {
                                VendorUpcomingWorkspaceCard(workspace: workspace)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Upcoming Work")
        .navigationBarTitleDisplayMode(.large)
    }
}
