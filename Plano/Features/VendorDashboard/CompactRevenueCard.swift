import SwiftUI

struct CompactRevenueCard: View {
    let todayTotal: String
    let isEmpty: Bool

    var body: some View {
        NavigationLink(value: DiscoveryRoute.vendorRevenue) {
            AppSurface {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "dollarsign.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.toneColor(.sage))
                            Text("Today's revenue")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                        }

                        Text(todayTotal)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .contentTransition(.numericText())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Today's revenue: \(todayTotal)")
        .accessibilityHint("Opens detailed revenue breakdown")
    }
}

#Preview("With Revenue") {
    NavigationStack {
        CompactRevenueCard(todayTotal: "$1,200", isEmpty: false)
            .padding(AppTheme.screenPadding)
            .background(AppBackdrop())
    }
}

#Preview("Empty") {
    NavigationStack {
        CompactRevenueCard(todayTotal: "$0", isEmpty: true)
            .padding(AppTheme.screenPadding)
            .background(AppBackdrop())
    }
}
