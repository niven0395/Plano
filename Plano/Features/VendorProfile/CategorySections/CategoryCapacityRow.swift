import SwiftUI

struct CategoryCapacityRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.Palette.textPrimary)
    }
}
