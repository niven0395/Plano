import SwiftUI

enum HostDateAvailability {
    case open
    case booked
    case hold
    case blocked
    case unavailable
    case outsideWindow

    var symbolName: String {
        switch self {
        case .open: "checkmark"
        case .booked: "lock.fill"
        case .hold: "clock.fill"
        case .blocked: "xmark.circle.fill"
        case .unavailable: "xmark"
        case .outsideWindow: "minus"
        }
    }

    var label: String {
        switch self {
        case .open: "Open"
        case .booked: "Booked"
        case .hold: "Hold"
        case .blocked: "Blocked by vendor"
        case .unavailable: "Unavailable"
        case .outsideWindow: "Outside window"
        }
    }

    var isSelectable: Bool {
        self == .open
    }
}

struct HostBookingCalendar: View {
    let vendorProfile: VendorProfile
    let availabilityRecords: [VendorAvailabilityRecord]
    @Binding var selectedDate: Date?

    @State private var visibleMonthStart: Date

    init(vendorProfile: VendorProfile, availabilityRecords: [VendorAvailabilityRecord], selectedDate: Binding<Date?>) {
        self.vendorProfile = vendorProfile
        self.availabilityRecords = availabilityRecords
        self._selectedDate = selectedDate
        let cal = Calendar.current
        if let date = selectedDate.wrappedValue {
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: date))
                ?? cal.startOfDay(for: .now)
            self._visibleMonthStart = State(initialValue: monthStart)
        } else {
            self._visibleMonthStart = State(initialValue: cal.startOfDay(for: .now))
        }
    }

    private var bookingWindowStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let leadDays = max(vendorProfile.leadTimeDays, 1)
        return calendar.date(byAdding: .day, value: leadDays, to: today) ?? today
    }

    private var bookingWindowEnd: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let effectiveDays: Int
        if vendorProfile.hasTimeslots {
            effectiveDays = min(vendorProfile.advanceBookingDays, vendorProfile.timeslotConfig.rollingWindowDays)
        } else {
            effectiveDays = vendorProfile.advanceBookingDays
        }
        return calendar.date(byAdding: .day, value: effectiveDays, to: today) ?? today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button("Previous month", systemImage: "chevron.left", action: previousMonth)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Spacer()

                Text(visibleMonthStart.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Spacer()

                Button("Next month", systemImage: "chevron.right", action: nextMonth)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                spacing: 8
            ) {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays.indices, id: \.self) { index in
                    if let day = calendarDays[index] {
                        HostCalendarDayCell(
                            day: day,
                            availability: dateAvailability(for: day),
                            isSelected: isSelected(day),
                            onSelect: { selectDate(day) }
                        )
                    } else {
                        Color.clear
                            .frame(height: 62)
                    }
                }
            }

            HostBookingCalendarLegend(hasHolds: hasHoldDates, hasBlocked: hasBlockedDates)

            if vendorProfile.leadTimeDays > 0 {
                Text("\(vendorProfile.leadTimeDays)-day lead time required")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
            }
        }
        .hapticFeedback(.selection, trigger: selectedDate)
    }

    // MARK: - Calendar Grid

    private var calendarDays: [Date?] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: visibleMonthStart),
              let firstWeek = Calendar.current.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = Calendar.current.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1)) else {
            return []
        }

        var days: [Date?] = []
        var date = firstWeek.start

        while date < lastWeek.end {
            if Calendar.current.isDate(date, equalTo: visibleMonthStart, toGranularity: .month) {
                days.append(date)
            } else {
                days.append(nil)
            }

            date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? lastWeek.end
        }

        return days
    }

    // MARK: - Availability

    private func dateAvailability(for date: Date) -> HostDateAvailability {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)

        // Outside booking window
        guard normalizedDate >= bookingWindowStart && normalizedDate <= bookingWindowEnd else {
            return .outsideWindow
        }

        // Check override records
        if let record = availabilityRecords.first(where: {
            guard let recordDate = $0.date else { return false }
            return calendar.isDate(recordDate, inSameDayAs: normalizedDate)
        }) {
            switch VendorAvailabilityStatus(rawValue: record.status) {
            case .booked:
                return .booked
            case .blocked:
                return .blocked
            case .hold:
                return .hold
            case nil:
                break
            }
        }

        // Check weekly schedule
        if vendorProfile.weeklySchedule.isAvailable(on: date) {
            return .open
        }

        return .unavailable
    }

    private var hasHoldDates: Bool {
        availabilityRecords.contains { $0.status == VendorAvailabilityStatus.hold.rawValue }
    }

    private var hasBlockedDates: Bool {
        availabilityRecords.contains { $0.status == VendorAvailabilityStatus.blocked.rawValue }
    }

    private func isSelected(_ day: Date) -> Bool {
        guard let selectedDate else { return false }
        return Calendar.current.isDate(day, inSameDayAs: selectedDate)
    }

    private func selectDate(_ day: Date) {
        guard dateAvailability(for: day).isSelectable else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            selectedDate = Calendar.current.startOfDay(for: day)
        }
    }

    private func previousMonth() {
        withAnimation(AppAnimation.transition) {
            visibleMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: visibleMonthStart) ?? visibleMonthStart
        }
    }

    private func nextMonth() {
        withAnimation(AppAnimation.transition) {
            visibleMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonthStart) ?? visibleMonthStart
        }
    }
}

// MARK: - Day Cell

struct HostCalendarDayCell: View {
    let day: Date
    let availability: HostDateAvailability
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Text(day.formatted(.dateTime.day()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(textColor)

                Image(systemName: availability.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            }
            .opacity(opacity)
            .animation(.spring(duration: 0.25, bounce: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!availability.isSelectable)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: AnyShapeStyle {
        switch availability {
        case .open:
            AnyShapeStyle(AppTheme.toneBackground(.sage))
        case .booked:
            AnyShapeStyle(AppTheme.toneBackground(.coral))
        case .hold:
            AnyShapeStyle(AppTheme.toneBackground(.gold))
        case .blocked:
            AnyShapeStyle(AppTheme.toneBackground(.coral).opacity(0.5))
        case .unavailable:
            AnyShapeStyle(AppTheme.Palette.chrome)
        case .outsideWindow:
            AnyShapeStyle(AppTheme.Palette.surface)
        }
    }

    private var textColor: AnyShapeStyle {
        switch availability {
        case .open, .booked, .hold:
            AnyShapeStyle(AppTheme.Palette.textPrimary)
        case .blocked:
            AnyShapeStyle(AppTheme.Palette.textSecondary)
        case .unavailable:
            AnyShapeStyle(AppTheme.Palette.subdued)
        case .outsideWindow:
            AnyShapeStyle(AppTheme.Palette.subdued)
        }
    }

    private var iconColor: AnyShapeStyle {
        switch availability {
        case .open:
            AnyShapeStyle(AppTheme.toneColor(.sage))
        case .booked:
            AnyShapeStyle(AppTheme.toneColor(.coral))
        case .hold:
            AnyShapeStyle(AppTheme.toneColor(.gold))
        case .blocked:
            AnyShapeStyle(AppTheme.toneColor(.coral))
        case .unavailable:
            AnyShapeStyle(AppTheme.Palette.textSecondary)
        case .outsideWindow:
            AnyShapeStyle(AppTheme.Palette.subdued)
        }
    }

    private var borderColor: Color {
        if isSelected {
            return AppTheme.Palette.accent
        }

        switch availability {
        case .booked, .blocked:
            return AppTheme.toneColor(.coral).opacity(0.28)
        case .open:
            return AppTheme.Palette.border
        default:
            return AppTheme.Palette.border.opacity(0.55)
        }
    }

    private var opacity: Double {
        switch availability {
        case .open, .booked, .hold:
            1
        case .blocked:
            0.8
        case .unavailable:
            0.7
        case .outsideWindow:
            0.45
        }
    }

    private var accessibilityLabel: String {
        let dateLabel = day.formatted(date: .abbreviated, time: .omitted)
        return "\(dateLabel), \(availability.label)"
    }
}

// MARK: - Legend

private struct HostBookingCalendarLegend: View {
    let hasHolds: Bool
    let hasBlocked: Bool

    var body: some View {
        HStack(spacing: 10) {
            legendItem(title: "Open", color: AppTheme.toneColor(.sage))
            legendItem(title: "Unavailable", color: AppTheme.Palette.chrome)
            legendItem(title: "Booked", color: AppTheme.toneColor(.coral))
            if hasBlocked {
                legendItem(title: "Blocked", color: AppTheme.toneColor(.coral).opacity(0.5))
            }
            if hasHolds {
                legendItem(title: "Hold", color: AppTheme.toneColor(.gold))
            }
        }
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
    }
}
