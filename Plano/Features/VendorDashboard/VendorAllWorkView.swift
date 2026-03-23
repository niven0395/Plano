import SwiftUI

struct VendorAllWorkView: View {
    @Environment(EventWorkspaceStore.self) private var workspaceStore
    @Environment(AppRouter.self) private var router

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
                            Button {
                                router.openVendorEventWorkspace(workspace.id)
                            } label: {
                                VendorUpcomingWorkspaceCard(workspace: workspace)
                            }
                            .buttonStyle(.plain)
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
