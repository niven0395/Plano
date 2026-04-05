import SwiftUI

struct CategoryTextLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(AppTheme.Palette.textSecondary)
    }
}
