import SwiftUI

struct InsightsMetricCard: View {
    let label: String
    let value: String
    let trend: Double
    let tone: AccentTone

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.toneColor(tone))
                        .frame(width: 7, height: 7)
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }

                Text(value)
                    .font(.system(size: 28, weight: .light))
                    .tracking(-0.8)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .minimumScaleFactor(0.7)

                InsightsTrendIndicator(trend: trend)
            }
        }
    }
}
