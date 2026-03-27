import SwiftUI

struct VendorArtworkPanel: View {
    let profileImagePath: String?
    var listingImagePath: String? = nil
    let tone: AccentTone
    var symbolName: String? = nil
    var height: CGFloat = 240

    private var effectiveImagePath: String? {
        if let listingImagePath, !listingImagePath.isEmpty {
            return listingImagePath
        }
        return profileImagePath
    }

    var body: some View {
        if let path = effectiveImagePath, !path.isEmpty {
            PlanoImage(
                storagePath: path,
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
