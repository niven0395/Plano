import SwiftUI

struct ResponsePerformanceRow: View {
    let responseTime: String
    let rating: ResponseRating

    var body: some View {
        AppSurface {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.subdued)

                Text("Avg. response time")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Spacer()

                Text(responseTime)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                StatusBadge(title: rating.label, tone: rating.tone)
            }
        }
    }
}

#Preview("Fast") {
    ResponsePerformanceRow(responseTime: "2.4h", rating: .fast)
        .padding(AppTheme.screenPadding)
        .background(AppBackdrop())
}

#Preview("Good") {
    ResponsePerformanceRow(responseTime: "6.1h", rating: .good)
        .padding(AppTheme.screenPadding)
        .background(AppBackdrop())
}

#Preview("Fair") {
    ResponsePerformanceRow(responseTime: "18h", rating: .fair)
        .padding(AppTheme.screenPadding)
        .background(AppBackdrop())
}
