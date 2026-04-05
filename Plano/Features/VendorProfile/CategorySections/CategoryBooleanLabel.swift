import SwiftUI

struct CategoryBooleanLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.Palette.textSecondary)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
    }
}
