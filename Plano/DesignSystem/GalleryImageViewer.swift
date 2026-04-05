import SwiftUI

struct GalleryImageViewer: View {
    let images: [VendorGalleryImage]
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(images: [VendorGalleryImage], startIndex: Int) {
        self.images = images
        self._currentIndex = State(initialValue: startIndex)
    }

    init(storagePaths: [String], startIndex: Int) {
        self.images = storagePaths.enumerated().map { index, path in
            VendorGalleryImage(storagePath: path, displayOrder: index)
        }
        self._currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    ZoomableImagePage(image: image)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .principal) {
                    if images.count > 1 {
                        Text("\(currentIndex + 1) of \(images.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(AppAnimation.transition, value: currentIndex)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ZoomableImagePage: View {
    let image: VendorGalleryImage
    @State private var scale: CGFloat = 1
    @GestureState private var magnification: CGFloat = 1

    private var effectiveScale: CGFloat {
        max(scale * magnification, 1)
    }

    var body: some View {
        PlanoImage(
            storagePath: image.storagePath,
            size: .standard,
            cornerRadius: 0,
            contentMode: .fit
        )
        .scaleEffect(effectiveScale)
        .gesture(
            MagnifyGesture()
                .updating($magnification) { value, state, _ in
                    state = value.magnification
                }
                .onEnded { value in
                    let newScale = scale * value.magnification
                    withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                        scale = newScale < 1.1 ? 1 : min(newScale, 4)
                    }
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                scale = scale > 1.1 ? 1 : 2
            }
        }
    }
}
