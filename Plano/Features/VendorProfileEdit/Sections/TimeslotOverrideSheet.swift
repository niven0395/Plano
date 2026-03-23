import SwiftUI

struct TimeslotOverrideSheet: View {
    let store: VendorProfileEditStore
    let date: Date
    let timeslotBookings: [VendorTimeslotBookingRecord]

    var body: some View {
        NavigationStack {
            List {
                if slots.isEmpty {
                    ContentUnavailableView(
                        "No Slots",
                        systemImage: "clock",
                        description: Text("Timeslot configuration does not produce any slots for this date.")
                    )
                } else {
                    ForEach(slots) { slot in
                        SlotRow(store: store, date: date, slot: slot)
                    }
                }
            }
            .navigationTitle(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var slots: [TimeslotOption] {
        store.draft.timeslotConfig.generatedSlots(for: date, existingBookings: timeslotBookings)
    }
}

// MARK: - Slot Row

private struct SlotRow: View {
    let store: VendorProfileEditStore
    let date: Date
    let slot: TimeslotOption

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(slot.timeRangeLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Spacer()

            switch slot.status {
            case .available:
                Button {
                    Task {
                        await store.blockTimeslot(on: date, slot: slot)
                    }
                } label: {
                    Text("Block")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.Palette.elevatedSurface, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(AppTheme.Palette.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

            case .blocked:
                Button {
                    Task {
                        await store.unblockTimeslot(on: date, slot: slot)
                    }
                } label: {
                    Text("Unblock")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.Palette.elevatedSurface, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(AppTheme.Palette.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

            case .hold:
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.toneColor(.gold))

                    Text("Hold")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.gold))
                }

            case .booked:
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.toneColor(.coral))

                    Text("Booked")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.coral))
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(slot.timeRangeLabel), \(accessibilityStatusLabel)")
    }

    private var statusColor: Color {
        switch slot.status {
        case .available: AppTheme.toneColor(.sage)
        case .blocked: AppTheme.Palette.subdued
        case .hold: AppTheme.toneColor(.gold)
        case .booked: AppTheme.toneColor(.coral)
        }
    }

    private var accessibilityStatusLabel: String {
        switch slot.status {
        case .available: "Available"
        case .blocked: "Blocked"
        case .hold: "On hold"
        case .booked: "Booked"
        }
    }
}
