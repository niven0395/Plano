import SwiftUI

/// A pinned bottom action bar with a frosted material background and hairline top divider.
///
/// Use via `.safeAreaInset(edge: .bottom)` on a `ScrollView`. The caller provides
/// the leading (optional) and trailing view content; the bar owns only the chrome
/// (material, border, padding).
///
/// ```swift
/// .safeAreaInset(edge: .bottom) {
///     AppFloatingActionBar {
///         StartingAtBlock(price: "$450")
///     } trailing: {
///         Button("Request booking") { ... }
///             .buttonStyle(AppFloatingActionBarButtonStyle())
///     }
/// }
/// ```
struct AppFloatingActionBar<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            leading
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.Palette.border)
                .frame(height: 1)
        }
    }
}

/// Capsule-shaped button style tuned for `AppFloatingActionBar`.
/// More compact than `PrimaryActionButtonStyle` since the bar adds its own padding.
struct AppFloatingActionBarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Palette.accentForeground)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                AppTheme.Palette.accent.opacity(configuration.isPressed ? 0.88 : 1),
                in: Capsule()
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
            .hapticFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { old, new in
                !old && new
            }
    }
}

/// A stacked "Starting at / $X" block intended for use as `leading` content in
/// `AppFloatingActionBar`. Kept here because it's the canonical pairing.
struct AppFloatingActionBarPriceBlock: View {
    let caption: String
    let priceLabel: String

    init(caption: String = "Starting at", priceLabel: String) {
        self.caption = caption
        self.priceLabel = priceLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.Palette.subdued)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(priceLabel)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
