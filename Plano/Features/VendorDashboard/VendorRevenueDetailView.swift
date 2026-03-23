import SwiftUI

struct VendorRevenueDetailView: View {
    @Environment(VendorDashboardStore.self) private var store
    @Environment(InboxStore.self) private var inboxStore
    @State private var selectedRange: RevenueTimeRange = .today

    private var snapshot: RevenueSnapshot {
        store.revenueSnapshot(for: selectedRange)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    title: "Revenue",
                    subtitle: "Breakdown of confirmed, pending, and completed revenue"
                )

                RevenueFilterChips(selectedRange: $selectedRange)

                if snapshot.isEmpty {
                    EmptyStateCard(
                        symbolName: "chart.bar",
                        title: "No revenue yet",
                        message: "Revenue from confirmed and completed bookings will appear here."
                    )
                } else {
                    revenueContent
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Revenue")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var revenueContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Total earned")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)

                Text(snapshot.totalEarnedLabel)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 0) {
                RevenueColumn(
                    label: "Confirmed",
                    value: snapshot.confirmedLabel,
                    tone: .sage
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                RevenueColumn(
                    label: "Pending deposits",
                    value: snapshot.pendingLabel,
                    tone: .gold
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                RevenueColumn(
                    label: "Completed",
                    value: snapshot.completedLabel,
                    tone: .blue
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            RevenueBarChart(snapshot: snapshot)

            if !snapshot.pendingItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pending transactions")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)

                    ForEach(snapshot.pendingItems) { item in
                        PendingTransactionRow(item: item) { conversationID in
                            Task {
                                await inboxStore.vendorConfirmPayment(in: conversationID)
                                await store.load()
                            }
                        }

                        if item.id != snapshot.pendingItems.last?.id {
                            Divider()
                        }
                    }
                }
            }

            if !snapshot.confirmedItems.isEmpty {
                RevenueItemSummaryRow(
                    title: "Confirmed",
                    count: snapshot.confirmedCount,
                    total: snapshot.confirmedLabel,
                    tone: .sage
                )
            }

            if !snapshot.completedItems.isEmpty {
                RevenueItemSummaryRow(
                    title: "Completed",
                    count: snapshot.completedCount,
                    total: snapshot.completedLabel,
                    tone: .blue
                )
            }
        }
    }
}
