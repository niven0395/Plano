import SwiftUI

struct ProfileCompletenessCard: View {
    let completeness: Int
    let recommendation: String

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(completeness)% complete")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(recommendation)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                HStack(spacing: 8) {
                    Text("Edit listing")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
                .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Edit business profile, \(completeness)% complete")
    }
}
