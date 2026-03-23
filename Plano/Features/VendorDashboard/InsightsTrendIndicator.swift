import SwiftUI

struct InsightsTrendIndicator: View {
    let trend: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbolName)
                .font(.caption2.weight(.bold))
            Text(formattedTrend)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(trendColor)
    }

    private var symbolName: String {
        if trend > 0.5 { return "arrow.up.right" }
        if trend < -0.5 { return "arrow.down.right" }
        return "arrow.right"
    }

    private var trendColor: Color {
        if trend > 0.5 { return AppTheme.toneColor(.sage) }
        if trend < -0.5 { return AppTheme.toneColor(.coral) }
        return AppTheme.Palette.subdued
    }

    private var formattedTrend: String {
        let abs = abs(trend)
        if abs < 0.1 { return "—" }
        return String(format: "%+.0f%%", trend)
    }
}
