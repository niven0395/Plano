import SwiftUI

/// A compact metadata ribbon: `★ 4.9 (127) · Responds in 2h · Verified`.
///
/// Renders each non-nil `SignalItem` with its icon + label, separated by a small
/// 3pt dot. Line-limited to 1 line. Designed for hero cards, result cards, and
/// context headers where density + scannability matter.
///
/// Nil items and items with empty text are skipped automatically, so callers can
/// build the list conditionally without filter churn:
///
/// ```swift
/// SignalRow(items: [
///     .rating(value: "4.9", count: 127),
///     .text("Responds in \(vendor.responseTime)"),
///     vendor.badge.isEmpty ? nil : .badge(vendor.badge, tone: .sage)
/// ])
/// ```
struct SignalRow: View {
    let items: [SignalItem?]

    init(items: [SignalItem?]) {
        self.items = items
    }

    private var visibleItems: [SignalItem] {
        items.compactMap { $0 }.filter { !$0.isEmpty }
    }

    var body: some View {
        let visible = visibleItems
        HStack(spacing: 10) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, item in
                SignalItemView(item: item)
                if index < visible.count - 1 {
                    Circle()
                        .fill(AppTheme.Palette.textSecondary.opacity(0.35))
                        .frame(width: 3, height: 3)
                        .accessibilityHidden(true)
                }
            }
        }
        .lineLimit(1)
    }
}

/// A single ribbon entry: icon + text with optional color tone.
struct SignalItem {
    let symbolName: String?
    let label: String
    let accentText: String?
    let tone: AccentTone?

    var isEmpty: Bool {
        label.trimmingCharacters(in: .whitespaces).isEmpty
            && (accentText?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
    }

    // MARK: Factories

    static func text(_ label: String, symbolName: String? = nil) -> SignalItem {
        SignalItem(symbolName: symbolName, label: label, accentText: nil, tone: nil)
    }

    static func rating(value: String, count: Int) -> SignalItem {
        SignalItem(
            symbolName: "star.fill",
            label: value,
            accentText: "(\(count))",
            tone: .gold
        )
    }

    static func badge(_ label: String, tone: AccentTone = .sage, symbolName: String = "checkmark.seal.fill") -> SignalItem {
        SignalItem(symbolName: symbolName, label: label, accentText: nil, tone: tone)
    }
}

private struct SignalItemView: View {
    let item: SignalItem

    var body: some View {
        HStack(spacing: 4) {
            if let symbolName = item.symbolName {
                Image(systemName: symbolName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(iconStyle)
                    .accessibilityHidden(true)
            }

            Text(item.label)
                .font(.subheadline.weight(item.tone != nil ? .semibold : .regular))
                .foregroundStyle(labelStyle)

            if let accentText = item.accentText {
                Text(accentText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var iconStyle: Color {
        if let tone = item.tone {
            return AppTheme.toneColor(tone)
        }
        return AppTheme.Palette.textSecondary
    }

    private var labelStyle: Color {
        if let tone = item.tone {
            switch tone {
            case .sage, .gold:
                return AppTheme.toneColor(tone)
            default:
                return AppTheme.Palette.textPrimary
            }
        }
        return AppTheme.Palette.textSecondary
    }
}
