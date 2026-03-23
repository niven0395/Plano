import SwiftUI

struct EventsView: View {
    let store: EventsStore
    @Environment(EventWorkspaceStore.self) private var workspaceStore
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                vendorContent
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.large)
    }

    private var vendorContent: some View {
        let workspaces = workspaceStore.vendorWorkspaces

        return VStack(alignment: .leading, spacing: 22) {
            SectionHeader(
                title: "Upcoming jobs",
                subtitle: workspaces.isEmpty
                    ? "Confirmed work will appear here."
                    : "\(workspaces.count) confirmed events"
            )

            if workspaces.isEmpty {
                EmptyStateCard(
                    symbolName: "calendar.badge.exclamationmark",
                    title: "No active events yet",
                    message: "Confirmed vendor work will surface here as bookings land."
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(workspaces) { workspace in
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
    }
}
