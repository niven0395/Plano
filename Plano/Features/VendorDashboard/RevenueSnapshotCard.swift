import SwiftUI

struct RevenueSnapshotCard: View {
    let snapshot: RevenueSnapshot
    @Binding var selectedRange: RevenueTimeRange
    var onConfirmPayment: ((UUID) -> Void)?
    @State private var isExpanded = false

    var body: some View {
        if snapshot.isEmpty {
            EmptyStateCard(
                symbolName: "chart.bar",
                title: "No revenue yet",
                message: "Revenue from confirmed and completed bookings will appear here."
            )
        } else {
            AppSurface {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Revenue")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.subdued)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }

                    RevenueFilterChips(selectedRange: $selectedRange)

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

                    if isExpanded {
                        RevenueExpandedSection(
                            snapshot: snapshot,
                            onConfirmPayment: onConfirmPayment
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.35)) {
                    isExpanded.toggle()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand revenue details")
        }
    }
}

// MARK: - Filter Chips

struct RevenueFilterChips: View {
    @Binding var selectedRange: RevenueTimeRange

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RevenueTimeRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    FilterChip(title: range.rawValue, isSelected: selectedRange == range)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filter \(range.rawValue)")
            }
        }
    }
}

// MARK: - Column

struct RevenueColumn: View {
    let label: String
    let value: String
    let tone: AccentTone

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(AppTheme.toneColor(tone))
                .frame(width: 8, height: 8)

            Text(value)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Expanded Section

struct RevenueExpandedSection: View {
    let snapshot: RevenueSnapshot
    var onConfirmPayment: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Total earned")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)

                Text(snapshot.totalEarnedLabel)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .contentTransition(.numericText())
            }

            RevenueBarChart(snapshot: snapshot)

            if !snapshot.pendingItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pending transactions")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)

                    ForEach(snapshot.pendingItems) { item in
                        PendingTransactionRow(
                            item: item,
                            onConfirmPayment: onConfirmPayment
                        )

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

// MARK: - Bar Chart

struct RevenueBarChart: View {
    let snapshot: RevenueSnapshot

    private var maxCents: Int {
        max(snapshot.confirmedCents, snapshot.pendingCents, snapshot.completedCents, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RevenueBar(
                label: "Confirmed",
                cents: snapshot.confirmedCents,
                maxCents: maxCents,
                tone: .sage
            )
            RevenueBar(
                label: "Pending",
                cents: snapshot.pendingCents,
                maxCents: maxCents,
                tone: .gold
            )
            RevenueBar(
                label: "Completed",
                cents: snapshot.completedCents,
                maxCents: maxCents,
                tone: .blue
            )
        }
        .animation(.snappy, value: snapshot)
    }
}

private struct RevenueBar: View {
    let label: String
    let cents: Int
    let maxCents: Int
    let tone: AccentTone

    private var fraction: CGFloat {
        guard maxCents > 0 else { return 0 }
        return CGFloat(cents) / CGFloat(maxCents)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.subdued)

                Spacer()

                Text(CurrencyValueFormatter.label(forCents: cents))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.toneColor(tone))
                    .frame(width: max(geometry.size.width * fraction, fraction > 0 ? 4 : 0))
            }
            .frame(height: 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.Palette.chrome.opacity(0.4))
            )
        }
    }
}

// MARK: - Pending Transaction Row

struct PendingTransactionRow: View {
    let item: RevenueLineItem
    var onConfirmPayment: ((UUID) -> Void)?

    @State private var isPresentingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.hostName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("\(item.eventTitle) · \(item.eventDateLabel)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text(item.amountLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
            }

            if onConfirmPayment != nil {
                Button("Confirm received") {
                    isPresentingConfirmation = true
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .confirmationDialog(
                    "Confirm payment received",
                    isPresented: $isPresentingConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Confirm received") {
                        onConfirmPayment?(item.conversationID)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will mark \(item.amountLabel) from \(item.hostName) as paid and lock in the booking.")
                }
            }
        }
    }
}

// MARK: - Summary Row

struct RevenueItemSummaryRow: View {
    let title: String
    let count: Int
    let total: String
    let tone: AccentTone

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppTheme.toneColor(tone))
                .frame(width: 8, height: 8)

            Text("\(count) \(title.lowercased())")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)

            Spacer()

            Text(total)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Previews

#Preview("With Data") {
    @Previewable @State var range: RevenueTimeRange = .allTime
    RevenueSnapshotCard(
        snapshot: RevenueSnapshot(
            confirmedCents: 480_000,
            confirmedLabel: "$4,800",
            confirmedCount: 2,
            confirmedItems: [
                RevenueLineItem(
                    id: UUID(), conversationID: UUID(),
                    hostName: "Maya Chen", eventTitle: "Garden Dinner",
                    eventDateLabel: "April 15, 2026", amountCents: 240_000,
                    amountLabel: "$2,400", paymentType: .deposit,
                    requestedAt: .now, confirmedAt: .now, stage: .paid
                ),
            ],
            pendingCents: 80_000,
            pendingLabel: "$800",
            pendingCount: 1,
            pendingItems: [
                RevenueLineItem(
                    id: UUID(), conversationID: UUID(),
                    hostName: "Jordan Brooks", eventTitle: "Cocktail Night",
                    eventDateLabel: "May 1, 2026", amountCents: 80_000,
                    amountLabel: "$800", paymentType: .deposit,
                    requestedAt: .now, confirmedAt: nil, stage: .paymentRequested
                ),
            ],
            completedCents: 640_000,
            completedLabel: "$6,400",
            completedCount: 2,
            completedItems: []
        ),
        selectedRange: $range,
        onConfirmPayment: { _ in }
    )
    .padding(AppTheme.screenPadding)
    .background(AppBackdrop())
}

#Preview("Empty") {
    @Previewable @State var range: RevenueTimeRange = .allTime
    RevenueSnapshotCard(
        snapshot: .empty,
        selectedRange: $range
    )
    .padding(AppTheme.screenPadding)
    .background(AppBackdrop())
}

#Preview("Expanded") {
    @Previewable @State var range: RevenueTimeRange = .allTime
    ScrollView {
        RevenueSnapshotCard(
            snapshot: RevenueSnapshot(
                confirmedCents: 480_000,
                confirmedLabel: "$4,800",
                confirmedCount: 2,
                confirmedItems: [
                    RevenueLineItem(
                        id: UUID(), conversationID: UUID(),
                        hostName: "Maya Chen", eventTitle: "Garden Dinner",
                        eventDateLabel: "April 15, 2026", amountCents: 240_000,
                        amountLabel: "$2,400", paymentType: .deposit,
                        requestedAt: .now, confirmedAt: .now, stage: .paid
                    ),
                ],
                pendingCents: 120_000,
                pendingLabel: "$1,200",
                pendingCount: 2,
                pendingItems: [
                    RevenueLineItem(
                        id: UUID(), conversationID: UUID(),
                        hostName: "Jordan Brooks", eventTitle: "Cocktail Night",
                        eventDateLabel: "May 1, 2026", amountCents: 80_000,
                        amountLabel: "$800", paymentType: .deposit,
                        requestedAt: .now, confirmedAt: nil, stage: .paymentRequested
                    ),
                    RevenueLineItem(
                        id: UUID(), conversationID: UUID(),
                        hostName: "Lena Park", eventTitle: "Birthday Bash",
                        eventDateLabel: "May 10, 2026", amountCents: 40_000,
                        amountLabel: "$400", paymentType: .fullPayment,
                        requestedAt: .now, confirmedAt: nil, stage: .paymentRequested
                    ),
                ],
                completedCents: 640_000,
                completedLabel: "$6,400",
                completedCount: 2,
                completedItems: []
            ),
            selectedRange: $range,
            onConfirmPayment: { _ in }
        )
        .padding(AppTheme.screenPadding)
    }
    .background(AppBackdrop())
}
