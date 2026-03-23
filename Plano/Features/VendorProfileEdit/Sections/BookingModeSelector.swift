import SwiftUI

struct BookingModeSelector: View {
    @Binding var bookingMode: BookingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How do you accept bookings?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Choose the clearest path from discovery to a confirmed date.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            VStack(spacing: 12) {
                ForEach(BookingMode.allCases) { mode in
                    Button {
                        bookingMode = mode
                    } label: {
                        BookingModeOptionCard(
                            title: title(for: mode),
                            ctaLabel: mode.title,
                            subtitle: subtitle(for: mode),
                            isSelected: bookingMode == mode
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .hapticFeedback(.selection, trigger: bookingMode)
        }
    }

    private func subtitle(for mode: BookingMode) -> String {
        switch mode {
        case .acceptOnline:
            "Hosts can book your available dates directly."
        case .requestOnly:
            "Hosts submit a date. You review before confirming."
        case .inquiryOnly:
            "Hosts message you to start the conversation."
        }
    }

    private func title(for mode: BookingMode) -> String {
        switch mode {
        case .acceptOnline:
            "Instant booking"
        case .requestOnly:
            "Request & review"
        case .inquiryOnly:
            "Inquiry only"
        }
    }
}

private struct BookingModeOptionCard: View {
    let title: String
    let ctaLabel: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(foregroundStyle)

                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(secondaryForegroundStyle)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ctaLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryForegroundStyle)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(chipBackgroundStyle, in: Capsule())
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(foregroundStyle)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                .stroke(isSelected ? AppTheme.Palette.accent : AppTheme.Palette.border, lineWidth: 1)
        }
    }

    private var foregroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.Palette.elevatedSurface)
        }

        return AnyShapeStyle(AppTheme.Palette.textPrimary)
    }

    private var secondaryForegroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.Palette.elevatedSurface.opacity(0.82))
        }

        return AnyShapeStyle(AppTheme.Palette.textSecondary)
    }

    private var backgroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.Palette.accent)
        }

        return AnyShapeStyle(AppTheme.Palette.elevatedSurface)
    }

    private var chipBackgroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.Palette.border)
        }

        return AnyShapeStyle(AppTheme.Palette.surface)
    }
}
