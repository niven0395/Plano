import SwiftUI

struct GenericCategorySection: View {
    let details: CategoryDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("This vendor has provided detailed information about their services.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }
}
