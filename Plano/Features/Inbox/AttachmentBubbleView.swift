import SwiftUI
import OSLog

struct AttachmentBubbleView: View {
    let attachment: MessageAttachment
    let isCurrentUser: Bool
    @State private var signedURL: URL?
    @State private var isLoadingURL = false
    @State private var isFullscreenPresented = false

    @Environment(InboxStore.self) private var inboxStore

    var body: some View {
        Group {
            if attachment.isImage {
                imageAttachmentView
            } else if attachment.isPDF {
                pdfAttachmentView
            }
        }
    }

    private var imageAttachmentView: some View {
        Button {
            isFullscreenPresented = true
        } label: {
            Group {
                if let signedURL {
                    AsyncImage(url: signedURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            imagePlaceholder(systemName: "exclamationmark.triangle")
                                .task { await refreshSignedURL() }
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 150)
                        @unknown default:
                            imagePlaceholder(systemName: "photo")
                        }
                    }
                } else {
                    imagePlaceholder(systemName: isLoadingURL ? "arrow.clockwise" : "photo")
                }
            }
            .frame(maxWidth: 200, maxHeight: 200)
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isCurrentUser ? AppTheme.Palette.accentForeground.opacity(0.2) : AppTheme.Palette.border,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .task {
            await loadSignedURL()
        }
        .fullScreenCover(isPresented: $isFullscreenPresented) {
            if let signedURL {
                FullscreenImageView(url: signedURL, fileName: attachment.fileName)
            }
        }
    }

    private var pdfAttachmentView: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundStyle(isCurrentUser ? AppTheme.Palette.accentForeground.opacity(0.8) : AppTheme.Palette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCurrentUser ? AppTheme.Palette.accentForeground : AppTheme.Palette.textPrimary)
                    .lineLimit(1)

                Text(attachment.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(isCurrentUser ? AppTheme.Palette.accentForeground.opacity(0.7) : AppTheme.Palette.subdued)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isCurrentUser
                ? AnyShapeStyle(AppTheme.Palette.accentForeground.opacity(0.15))
                : AnyShapeStyle(AppTheme.Palette.elevatedSurface),
            in: .rect(cornerRadius: 12)
        )
    }

    private func imagePlaceholder(systemName: String) -> some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.Palette.elevatedSurface)
            Image(systemName: systemName)
                .foregroundStyle(AppTheme.Palette.subdued)
        }
        .frame(width: 200, height: 150)
    }

    private func loadSignedURL() async {
        guard signedURL == nil, !isLoadingURL else { return }

        if let localURL = attachment.localURL {
            signedURL = localURL
            return
        }

        if let cached = attachment.signedURL {
            signedURL = cached
            return
        }

        isLoadingURL = true
        defer { isLoadingURL = false }

        do {
            let url = try await inboxStore.signedURL(for: attachment.storagePath)
            signedURL = url
        } catch {
            AppLogger.networking.error("Failed to load attachment URL: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Re-fetches a fresh signed URL when the cached one has expired (403).
    private func refreshSignedURL() async {
        guard !isLoadingURL else { return }
        isLoadingURL = true
        defer { isLoadingURL = false }

        do {
            let url = try await inboxStore.signedURL(for: attachment.storagePath)
            signedURL = url
        } catch {
            AppLogger.networking.error("Failed to refresh attachment URL: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct FullscreenImageView: View {
    let url: URL
    let fileName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Failed to load image")
                            .font(.subheadline)
                    }
                    .foregroundStyle(AppTheme.Palette.subdued)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct PendingAttachmentPreviewRow: View {
    let attachments: [PendingAttachment]
    let onRemove: (PendingAttachment) -> Void

    var body: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        ZStack(alignment: .topTrailing) {
                            if attachment.isImage {
                                if let uiImage = UIImage(data: attachment.data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(.rect(cornerRadius: 8))
                                }
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: "doc.fill")
                                        .font(.title3)
                                    Text(attachment.fileName)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .frame(width: 60, height: 60)
                                .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: 8))
                            }

                            Button {
                                onRemove(attachment)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.white, Color.red)
                            }
                            .offset(x: 4, y: -4)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
