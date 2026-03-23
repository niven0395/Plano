import SwiftUI

struct VendorArtworkPanel: View {
    let profileImagePath: String?
    let tone: AccentTone
    var symbolName: String? = nil
    var height: CGFloat = 240

    var body: some View {
        if let profileImagePath, !profileImagePath.isEmpty {
            PlanoImage(
                storagePath: profileImagePath,
                size: .standard,
                cornerRadius: AppTheme.cardCornerRadius,
                contentMode: .fill
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
        } else {
            EditorialArtworkPanel(
                tone: tone,
                symbolName: symbolName,
                height: height
            )
        }
    }
}
