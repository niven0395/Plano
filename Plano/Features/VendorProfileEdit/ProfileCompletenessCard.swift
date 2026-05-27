import SwiftUI

struct ProfileCompletenessCard: View {
    let completeness: Int
    let recommendation: String

    private var tone: AccentTone {
        if completeness >= 90 { return .sage }
        if completeness >= 50 { return .gold }
        return .coral
    }

    private var headline: String {
        if completeness >= 100 { return "Listing looks great" }
        if completeness >= 75 { return "Almost there" }
        if completeness >= 25 { return "Keep building" }
        return "Let's build your listing"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(headline)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .tracking(-0.4)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Spacer(minLength: 8)

                Text("\(completeness)%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.toneColor(tone))
                    .accessibilityHidden(true)
            }

            ProgressView(value: Double(completeness), total: 100)
                .progressViewStyle(.linear)
                .tint(AppTheme.toneColor(tone))
                .scaleEffect(x: 1, y: 1.4, anchor: .center)
                .animation(.snappy, value: completeness)

            HStack(alignment: .top, spacing: 8) {
                Text(recommendation)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.toneColor(tone))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.toneBackground(tone).opacity(0.55), in: .rect(cornerRadius: AppTheme.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .stroke(AppTheme.toneColor(tone).opacity(0.35), lineWidth: 1)
        }
        .shadow(color: AppTheme.Palette.shadow, radius: 14, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Listing \(completeness)% complete. \(recommendation)")
    }
}
