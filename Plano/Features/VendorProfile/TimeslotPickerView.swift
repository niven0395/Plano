import SwiftUI

struct TimeslotPickerView: View {
    let slots: [TimeslotOption]
    @Binding var selectedSlot: TimeslotOption?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available times")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            if slots.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Palette.subdued)
                    Text("No slots available for this date")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
                .padding(.vertical, 12)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(slots) { slot in
                        TimeslotCell(
                            slot: slot,
                            isSelected: selectedSlot?.id == slot.id,
                            onSelect: { selectSlot(slot) }
                        )
                    }
                }
            }
        }
    }

    private func selectSlot(_ slot: TimeslotOption) {
        guard slot.status == .available else { return }
        if selectedSlot?.id == slot.id {
            selectedSlot = nil
        } else {
            selectedSlot = slot
        }
    }
}

// MARK: - Timeslot Cell

private struct TimeslotCell: View {
    let slot: TimeslotOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(slot.timeRangeLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if slot.status != .available {
                    Text(statusLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(statusColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(backgroundColor, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(slot.status != .available)
        .accessibilityLabel("\(slot.timeRangeLabel), \(slot.status == .available ? "Available" : statusLabel)")
    }

    private var textColor: AnyShapeStyle {
        switch slot.status {
        case .available:
            AnyShapeStyle(AppTheme.Palette.textPrimary)
        case .booked, .blocked:
            AnyShapeStyle(AppTheme.Palette.subdued)
        case .hold:
            AnyShapeStyle(AppTheme.Palette.textPrimary)
        }
    }

    private var backgroundColor: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(AppTheme.toneBackground(.sage))
        }
        switch slot.status {
        case .available:
            return AnyShapeStyle(AppTheme.Palette.elevatedSurface)
        case .booked:
            return AnyShapeStyle(AppTheme.toneBackground(.coral).opacity(0.5))
        case .blocked:
            return AnyShapeStyle(AppTheme.Palette.chrome)
        case .hold:
            return AnyShapeStyle(AppTheme.toneBackground(.gold).opacity(0.5))
        }
    }

    private var borderColor: Color {
        if isSelected {
            return AppTheme.Palette.accent
        }
        switch slot.status {
        case .available:
            return AppTheme.Palette.border
        case .booked:
            return AppTheme.toneColor(.coral).opacity(0.28)
        case .blocked:
            return AppTheme.Palette.border.opacity(0.55)
        case .hold:
            return AppTheme.toneColor(.gold).opacity(0.28)
        }
    }

    private var statusLabel: String {
        switch slot.status {
        case .available: "Available"
        case .booked: "Booked"
        case .blocked: "Unavailable"
        case .hold: "On hold"
        }
    }

    private var statusColor: AnyShapeStyle {
        switch slot.status {
        case .available: AnyShapeStyle(AppTheme.toneColor(.sage))
        case .booked: AnyShapeStyle(AppTheme.toneColor(.coral))
        case .blocked: AnyShapeStyle(AppTheme.Palette.subdued)
        case .hold: AnyShapeStyle(AppTheme.toneColor(.gold))
        }
    }
}
