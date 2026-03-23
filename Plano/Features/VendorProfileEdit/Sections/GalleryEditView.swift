import PhotosUI
import SwiftUI

struct GalleryEditView: View {
    let store: VendorProfileEditStore
    @State private var selectedItems: [PhotosPickerItem] = []

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    private var remainingSlots: Int {
        max(5 - store.draft.galleryImages.count - store.pendingUploads.count, 0)
    }

    private var isFull: Bool {
        remainingSlots <= 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: remainingSlots, matching: .images) {
                    Label("Add photos", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isFull)

                Text("\(store.draft.galleryImages.count + store.pendingUploads.count) of 5 photos")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                    .frame(maxWidth: .infinity)

                if store.draft.galleryImages.isEmpty, store.pendingUploads.isEmpty {
                    EmptyStateCard(
                        symbolName: "photo.stack",
                        title: "No gallery images yet",
                        message: "Portfolio photos make the biggest difference once hosts start comparing similar vendors."
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.pendingUploads) { upload in
                            PendingUploadCell(upload: upload)
                        }

                        ForEach(store.draft.galleryImages) { image in
                            GalleryThumbnailCell(
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
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Gallery updated") {
            store.lastSaveOutcome = .idle
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

private struct GalleryThumbnailCell: View {
    let image: VendorGalleryImage
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Text(image.caption.isEmpty ? "Gallery image" : image.caption)
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textSecondary)
                .lineLimit(1)
        }
    }
}

private struct PendingUploadCell: View {
    let upload: ImageUploadProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(uiImage: upload.localImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(.rect(cornerRadius: AppTheme.smallCornerRadius))
                .clipped()
                .overlay {
                    ZStack {
                        Color.black.opacity(0.35)
                            .clipShape(.rect(cornerRadius: AppTheme.smallCornerRadius))

                        progressIndicator
                    }
                }

            Text("Uploading...")
                .font(.caption)
                .foregroundStyle(AppTheme.Palette.textSecondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var progressIndicator: some View {
        switch upload.state {
        case .processing:
            ProgressView()
                .tint(.white)
        case .uploading(let progress):
            CircularProgressView(progress: progress)
        case .failed(let message):
            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(8)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
        }
    }
}

private struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                .frame(width: 36, height: 36)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))
        }
    }
}
