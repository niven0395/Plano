import PhotosUI
import SwiftUI

struct VendorOnboardingSlideFourView: View {
    let store: VendorOnboardingStore
    @State private var selectedItems: [PhotosPickerItem] = []

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    private var remainingSlots: Int {
        max(5 - store.galleryImages.count - store.pendingUploads.count, 0)
    }

    private var isFull: Bool {
        remainingSlots <= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: "Show your work",
                subtitle: "Portfolio photos make the biggest difference when hosts compare vendors."
            )

            PhotosPicker(selection: $selectedItems, maxSelectionCount: remainingSlots, matching: .images) {
                Label("Add photos", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isFull)

            Text("\(store.galleryImages.count + store.pendingUploads.count) of 5 photos")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
                .frame(maxWidth: .infinity)

            if store.galleryImages.isEmpty, store.pendingUploads.isEmpty {
                EmptyStateCard(
                    symbolName: "photo.stack",
                    title: "No gallery images yet",
                    message: "Add up to 5 photos that represent your best work."
                )
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.pendingUploads) { upload in
                        OnboardingPendingUploadCell(upload: upload)
                    }

                    ForEach(store.galleryImages) { image in
                        OnboardingGalleryThumbnailCell(
                            image: image,
                            onDelete: {
                                Task {
                                    await store.removeGalleryImage(image)
                                }
                            }
                        )
                    }
                }
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }

            Task {
                let clamped = newItems.prefix(remainingSlots)
                for item in clamped {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await store.addGalleryImage(data: data)
                    }
                }
                selectedItems = []
            }
        }
    }
}

private struct OnboardingGalleryThumbnailCell: View {
    let image: VendorGalleryImage
    let onDelete: () -> Void

    var body: some View {
        PlanoImage(
            storagePath: image.storagePath,
            size: .thumbnail,
            cornerRadius: AppTheme.smallCornerRadius,
            contentMode: .fill
        )
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipped()
        .overlay(alignment: .topTrailing) {
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            .padding(6)
        }
    }
}

private struct OnboardingPendingUploadCell: View {
    let upload: ImageUploadProgress

    var body: some View {
        Image(uiImage: upload.localImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(.rect(cornerRadius: AppTheme.smallCornerRadius))
            .clipped()
            .overlay {
                Color.black.opacity(0.35)
                    .clipShape(.rect(cornerRadius: AppTheme.smallCornerRadius))
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
    }
}
