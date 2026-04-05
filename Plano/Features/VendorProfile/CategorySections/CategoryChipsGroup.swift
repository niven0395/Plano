import SwiftUI

struct CategoryChipsGroup: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Palette.subdued)

            Text(items.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
    }
}
