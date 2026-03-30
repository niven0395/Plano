import SwiftUI
import UIKit

enum AppTheme {
    static let screenPadding: CGFloat = 22
    static let cardCornerRadius: CGFloat = 30
    static let smallCornerRadius: CGFloat = 20
    static let compactCornerRadius: CGFloat = 12
    static let avatarSize: CGFloat = 48
    static let badgeSize: CGFloat = 7
    static let iconFrameSize: CGFloat = 36

    enum Palette {
        static let accent = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1)
                : UIColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1)
        })

        static let accentForeground = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1)
                : UIColor(red: 0.992, green: 0.988, blue: 0.981, alpha: 1)
        })

        static let backgroundTop = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1)
                : UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1)
        })

        static let backgroundBottom = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
                : UIColor(red: 0.91, green: 0.90, blue: 0.88, alpha: 1)
        })

        static let surface = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.14, green: 0.13, blue: 0.12, alpha: 1)
                : UIColor(red: 0.97, green: 0.965, blue: 0.955, alpha: 1)
        })

        static let elevatedSurface = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.17, blue: 0.15, alpha: 1)
                : UIColor(red: 0.992, green: 0.988, blue: 0.981, alpha: 1)
        })

        static let chrome = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.20, green: 0.19, blue: 0.17, alpha: 1)
                : UIColor(red: 0.90, green: 0.89, blue: 0.87, alpha: 1)
        })

        static let border = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.10)
                : UIColor(white: 0, alpha: 0.075)
        })

        static let textPrimary = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.93, green: 0.91, blue: 0.88, alpha: 1)
                : UIColor(red: 0.14, green: 0.13, blue: 0.12, alpha: 1)
        })

        static let textSecondary = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.62, green: 0.60, blue: 0.57, alpha: 1)
                : UIColor(red: 0.26, green: 0.24, blue: 0.22, alpha: 1)
        })

        static let subdued = Color(red: 0.48, green: 0.46, blue: 0.43)

        static let shadow = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0, alpha: 0.30)
                : UIColor(white: 0, alpha: 0.04)
        })

        // MARK: - Glassmorphism

        static let glassHighlight = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.08)
                : UIColor(white: 1, alpha: 0.55)
        })

        static let glassSubtle = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.05)
                : UIColor(white: 1, alpha: 0.34)
        })

        static let glassStroke = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.06)
                : UIColor(white: 1, alpha: 0.28)
        })

        static let inputFill = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.06)
                : UIColor(white: 1, alpha: 0.42)
        })

        static let chipFill = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.08)
                : UIColor(white: 1, alpha: 0.45)
        })
    }

    static func toneColor(_ tone: AccentTone) -> Color {
        switch tone {
        case .blue:
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.52, green: 0.58, blue: 0.64, alpha: 1)
                    : UIColor(red: 0.37, green: 0.42, blue: 0.47, alpha: 1)
            })
        case .sand:
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.72, green: 0.63, blue: 0.53, alpha: 1)
                    : UIColor(red: 0.58, green: 0.49, blue: 0.39, alpha: 1)
            })
        case .coral:
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.70, green: 0.53, blue: 0.47, alpha: 1)
                    : UIColor(red: 0.56, green: 0.39, blue: 0.33, alpha: 1)
            })
        case .sage:
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.56, green: 0.63, blue: 0.52, alpha: 1)
                    : UIColor(red: 0.41, green: 0.47, blue: 0.38, alpha: 1)
            })
        case .gold:
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.70, green: 0.58, blue: 0.44, alpha: 1)
                    : UIColor(red: 0.55, green: 0.44, blue: 0.30, alpha: 1)
            })
        }
    }

    static func toneBackground(_ tone: AccentTone) -> Color {
        toneColor(tone).opacity(0.12)
    }
}

enum AppSurfaceStyle {
    case regular
    case highlighted
}

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Palette.backgroundTop,
                    AppTheme.Palette.backgroundBottom,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppTheme.Palette.glassHighlight)
                .frame(width: 300, height: 300)
                .blur(radius: 55)
                .offset(x: 150, y: -260)

            EditorialArchShape()
                .fill(AppTheme.Palette.glassSubtle)
                .frame(width: 170, height: 220)
                .offset(x: -145, y: 170)

            RoundedRectangle(cornerRadius: 90, style: .continuous)
                .stroke(AppTheme.Palette.glassStroke, lineWidth: 1)
                .frame(width: 260, height: 260)
                .offset(x: 135, y: 235)
        }
        .ignoresSafeArea()
    }
}

struct AppSurface<Content: View>: View {
    private let style: AppSurfaceStyle
    private let compact: Bool
    private let content: Content

    init(style: AppSurfaceStyle = .regular, compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.style = style
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        let cornerRadius = compact ? AppTheme.smallCornerRadius : AppTheme.cardCornerRadius
        content
            .padding(compact ? 16 : 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundStyle, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(color: AppTheme.Palette.shadow, radius: compact ? 10 : 18, y: compact ? 6 : 12)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .regular:
            AnyShapeStyle(AppTheme.Palette.surface)
        case .highlighted:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        AppTheme.Palette.elevatedSurface,
                        AppTheme.Palette.elevatedSurface,
                        AppTheme.Palette.surface,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var borderColor: Color {
        switch style {
        case .regular:
            AppTheme.Palette.border
        case .highlighted:
            AppTheme.Palette.textPrimary.opacity(0.08)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 32, weight: .regular))
                .tracking(-1.1)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .lineSpacing(2)
            }
        }
    }
}

struct StatusBadge: View {
    let title: String
    let tone: AccentTone

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.toneColor(tone))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(AppTheme.toneBackground(tone), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.toneColor(tone).opacity(0.18), lineWidth: 1)
            }
    }
}

struct MetricTile: View {
    let metric: MetricSummary

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 8) {
                StatusBadge(title: metric.title, tone: metric.tone)

                Text(metric.value)
                    .font(.system(size: 26, weight: .light))
                    .tracking(-0.8)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .minimumScaleFactor(0.75)

                Text(metric.detail)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var expands: Bool = false

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isSelected ? AppTheme.Palette.elevatedSurface : AppTheme.Palette.textPrimary)
            .frame(maxWidth: expands ? .infinity : nil)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(chipBackground, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? AppTheme.Palette.accent : AppTheme.Palette.border, lineWidth: 1)
            }
            .animation(AppAnimation.feedback, value: isSelected)
    }

    private var chipBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.Palette.accent)
        }

        return AnyShapeStyle(AppTheme.Palette.chipFill)
    }
}

struct AvailabilityDateChip: View {
    @Binding var date: Date?

    private var isActive: Bool { date != nil }

    private var chipLabel: String {
        if let date {
            date.formatted(.dateTime.month(.abbreviated).day())
        } else {
            "Fits date"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Label(chipLabel, systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if isActive {
                Button("Clear date filter", systemImage: "xmark.circle.fill") {
                    date = nil
                }
                .labelStyle(.iconOnly)
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(isActive ? AppTheme.Palette.elevatedSurface : AppTheme.Palette.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(chipBackground, in: Capsule())
        .overlay {
            Capsule()
                .stroke(isActive ? AppTheme.Palette.accent : AppTheme.Palette.border, lineWidth: 1)
        }
        .overlay {
            DatePicker(
                "Availability date",
                selection: Binding(
                    get: { date ?? .now },
                    set: { date = $0 }
                ),
                in: Date.now...,
                displayedComponents: .date
            )
            .labelsHidden()
            .blendMode(.destinationOver)
        }
        .animation(AppAnimation.feedback, value: isActive)
    }

    private var chipBackground: some ShapeStyle {
        if isActive {
            return AnyShapeStyle(AppTheme.Palette.accent)
        }
        return AnyShapeStyle(AppTheme.Palette.chipFill)
    }
}

struct EmptyStateCard: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Palette.elevatedSurface)
                        .frame(width: 52, height: 52)

                    Image(systemName: symbolName)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                        .symbolEffect(.pulse.byLayer)
                }

                Text(title)
                    .font(.system(size: 24, weight: .regular))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.Palette.accentForeground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                AppTheme.Palette.accent.opacity(configuration.isPressed ? 0.88 : 1),
                in: .rect(cornerRadius: AppTheme.smallCornerRadius)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AppAnimation.press, value: configuration.isPressed)
            .hapticFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { old, new in
                !old && new
            }
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                configuration.isPressed ? AppTheme.Palette.glassHighlight : AppTheme.Palette.inputFill,
                in: .rect(cornerRadius: AppTheme.smallCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                    .stroke(AppTheme.Palette.border, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AppAnimation.press, value: configuration.isPressed)
            .hapticFeedback(.impact(weight: .light), trigger: configuration.isPressed) { old, new in
                !old && new
            }
    }
}

struct EditorialArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let archStartY = rect.minY + rect.height * 0.36
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: archStartY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: archStartY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { continue }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + rowHeight
        }

        return ArrangementResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: totalHeight)
        )
    }

    private struct ArrangementResult {
        let positions: [CGPoint]
        let size: CGSize
    }
}

struct MenuDropdownRow: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
            }

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Spacer()

            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
    }
}

struct EditorialArtworkPanel: View {
    let tone: AccentTone
    var symbolName: String? = nil
    var height: CGFloat = 240

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    AppTheme.Palette.glassHighlight,
                    AppTheme.toneBackground(tone).opacity(0.95),
                    AppTheme.Palette.chrome.opacity(0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(AppTheme.Palette.glassHighlight)
                .frame(width: 138, height: height * 0.72)
                .offset(x: 44, y: -12)

            EditorialArchShape()
                .fill(AppTheme.Palette.glassHighlight)
                .frame(width: 148, height: height * 0.78)
                .offset(x: -16, y: -6)

            Circle()
                .fill(AppTheme.toneColor(tone).opacity(0.12))
                .frame(width: 150, height: 150)
                .offset(x: -54, y: 52)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.Palette.accent.opacity(0.92))
                .frame(width: 74, height: 74)
                .offset(x: 22, y: 34)

            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(AppTheme.Palette.accentForeground)
                    .offset(x: 43, y: 31)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.Palette.glassStroke, lineWidth: 1)
        }
    }
}
