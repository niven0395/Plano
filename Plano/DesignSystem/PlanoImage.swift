import SwiftUI
import UIKit

struct PlanoImage: View {
    let storagePath: String?
    var size: ImageSize = .standard
    var cornerRadius: CGFloat = AppTheme.cardCornerRadius
    var contentMode: ContentMode = .fill
    var localImage: UIImage?

    @Environment(AppEnvironment.self) private var environment
    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.combined(with: .blurReplace).animation(.easeOut(duration: 0.3)))
            } else if storagePath != nil, !loadFailed {
                Rectangle()
                    .fill(AppTheme.Palette.chrome)
                    .shimmer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
        .task(id: taskID) {
            await loadImage()
        }
    }

    private var displayImage: UIImage? {
        localImage ?? loadedImage
    }

    private var taskID: String {
        "\(storagePath ?? ""):\(size.rawValue)"
    }

    private var placeholder: some View {
        Rectangle()
            .fill(AppTheme.Palette.elevatedSurface)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Palette.subdued)
            }
    }

    private func loadImage() async {
        guard let storagePath, !storagePath.isEmpty else {
            loadedImage = nil
            return
        }

        // Check local staging first (optimistic uploads)
        if let staged = await environment.imageCache.stagedImage(for: storagePath) {
            loadedImage = staged
            return
        }

        // Check cache (memory + disk)
        if let cached = await environment.imageCache.image(for: storagePath, size: size) {
            loadedImage = cached
            return
        }

        // Fetch from network
        do {
            let url = try await environment.services.mediaService.imageURL(for: storagePath, size: size)
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let image = UIImage(data: data) else {
                loadFailed = true
                return
            }

            await environment.imageCache.store(image, data: data, for: storagePath, size: size)
            loadedImage = image
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}
