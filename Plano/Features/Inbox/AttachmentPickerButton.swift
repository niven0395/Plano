import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AttachmentPickerButton: View {
    @Binding var selectedAttachments: [PendingAttachment]
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isPresentingDocumentPicker = false
    @State private var showAttachmentOptions = false

    let maxAttachments: Int

    init(selectedAttachments: Binding<[PendingAttachment]>, maxAttachments: Int = MessageAttachment.maxAttachmentsPerMessage) {
        self._selectedAttachments = selectedAttachments
        self.maxAttachments = maxAttachments
    }

    var body: some View {
        Menu {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: remainingSlots,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }

            Button {
                isPresentingDocumentPicker = true
            } label: {
                Label("Document", systemImage: "doc")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    selectedAttachments.count >= maxAttachments
                        ? AppTheme.Palette.subdued.opacity(0.4)
                        : AppTheme.Palette.accent
                )
        }
        .disabled(selectedAttachments.count >= maxAttachments)
        .accessibilityLabel("Attach file")
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                for item in newItems {
                    guard selectedAttachments.count < maxAttachments else { break }
                    await loadPhoto(item)
                }
                selectedPhotos = []
            }
        }
        .sheet(isPresented: $isPresentingDocumentPicker) {
            DocumentPickerView(selectedAttachments: $selectedAttachments, maxAttachments: maxAttachments)
        }
    }

    private var remainingSlots: Int {
        max(0, maxAttachments - selectedAttachments.count)
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        let mimeType: String
        let fileName: String
        let fileExtension: String

        if let contentType = item.supportedContentTypes.first {
            if contentType.conforms(to: .png) {
                mimeType = "image/png"
                fileExtension = "png"
            } else if contentType.conforms(to: .heic) {
                mimeType = "image/heic"
                fileExtension = "heic"
            } else {
                mimeType = "image/jpeg"
                fileExtension = "jpg"
            }
        } else {
            mimeType = "image/jpeg"
            fileExtension = "jpg"
        }

        fileName = "photo_\(UUID().uuidString.prefix(8)).\(fileExtension)"

        guard Int64(data.count) <= MessageAttachment.maxFileSizeBytes else { return }
        guard MessageAttachment.allowedMIMETypes.contains(mimeType) else { return }

        let attachment = PendingAttachment(
            id: UUID(),
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            fileSizeBytes: Int64(data.count)
        )

        await MainActor.run {
            selectedAttachments.append(attachment)
        }
    }
}

struct PendingAttachment: Identifiable, Hashable {
    let id: UUID
    let data: Data
    let fileName: String
    let mimeType: String
    let fileSizeBytes: Int64

    var isImage: Bool { mimeType.hasPrefix("image/") }
    var isPDF: Bool { mimeType == "application/pdf" }

    static func == (lhs: PendingAttachment, rhs: PendingAttachment) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var selectedAttachments: [PendingAttachment]
    let maxAttachments: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .jpeg, .png, .heic]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                guard parent.selectedAttachments.count < parent.maxAttachments else { break }
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                guard let data = try? Data(contentsOf: url) else { continue }
                guard Int64(data.count) <= MessageAttachment.maxFileSizeBytes else { continue }

                let mimeType: String
                if let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
                   let utType = UTType(typeID) {
                    if utType.conforms(to: .pdf) {
                        mimeType = "application/pdf"
                    } else if utType.conforms(to: .png) {
                        mimeType = "image/png"
                    } else if utType.conforms(to: .heic) {
                        mimeType = "image/heic"
                    } else {
                        mimeType = "image/jpeg"
                    }
                } else {
                    mimeType = "application/pdf"
                }

                guard MessageAttachment.allowedMIMETypes.contains(mimeType) else { continue }

                let attachment = PendingAttachment(
                    id: UUID(),
                    data: data,
                    fileName: url.lastPathComponent,
                    mimeType: mimeType,
                    fileSizeBytes: Int64(data.count)
                )

                parent.selectedAttachments.append(attachment)
            }
        }
    }
}
