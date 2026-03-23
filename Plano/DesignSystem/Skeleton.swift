import SwiftUI

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.7 : 0.3)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Primitives

struct SkeletonLine: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.compactCornerRadius)
            .fill(AppTheme.Palette.chrome)
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
            .shimmer()
    }

    static var short: SkeletonLine { SkeletonLine(width: 80) }
    static var medium: SkeletonLine { SkeletonLine(width: 140) }
    static var long: SkeletonLine { SkeletonLine(width: 220) }
}

struct SkeletonCircle: View {
    var size: CGFloat

    var body: some View {
        Circle()
            .fill(AppTheme.Palette.chrome)
            .frame(width: size, height: size)
            .shimmer()
    }
}

struct SkeletonRect: View {
    var height: CGFloat = 188
    var cornerRadius: CGFloat = AppTheme.cardCornerRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppTheme.Palette.chrome)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .shimmer()
    }
}

struct SkeletonCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        AppSurface {
            content
        }
    }
}

// MARK: - Previews

#Preview("Skeleton Primitives") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text("Lines")
                .font(.headline)
            SkeletonLine.short
            SkeletonLine.medium
            SkeletonLine.long
            SkeletonLine()

            Text("Circle")
                .font(.headline)
            HStack(spacing: 12) {
                SkeletonCircle(size: 26)
                SkeletonCircle(size: 40)
                SkeletonCircle(size: 52)
            }

            Text("Rect")
                .font(.headline)
            SkeletonRect()
            SkeletonRect(height: 100, cornerRadius: AppTheme.smallCornerRadius)

            Text("Card")
                .font(.headline)
            SkeletonCard {
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonLine.medium
                    SkeletonLine()
                    SkeletonLine.long
                }
            }
        }
        .padding(AppTheme.screenPadding)
    }
    .background(AppBackdrop())
}
