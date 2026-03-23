import SwiftUI

struct DateOverrideCalendar: View {
    let store: VendorProfileEditStore

    @State private var visibleMonthStart = Calendar.current.startOfDay(for: .now)
    @State private var lastTappedDate: Date?
    @State private var timeslotOverrideDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Block Dates")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

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
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays.indices, id: \.self) { index in
                    if let day = calendarDays[index] {
                        Button {
                            updateAvailability(for: day)
                        } label: {
                            Text(day.formatted(.dateTime.day()))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(dayTextColor(for: day))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background { dayBackground(for: day) }
                                .opacity(dayOpacity(for: day))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!store.canEditAvailabilityOverride(on: day))
                        .accessibilityLabel(accessibilityLabel(for: day))
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
            .hapticFeedback(.impact(weight: .light), trigger: lastTappedDate)

            if hasBlockedDates || hasBookedDates {
                HStack(spacing: 12) {
                    if hasBlockedDates {
                        legendItem(title: "Blocked", color: AppTheme.toneColor(.coral))
                    }
                    if hasBookedDates {
                        legendItem(title: "Booked", color: AppTheme.toneColor(.coral).opacity(0.5))
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { timeslotOverrideDate != nil },
            set: { if !$0 { timeslotOverrideDate = nil } }
        )) {
            if let date = timeslotOverrideDate {
                TimeslotOverrideSheet(
                    store: store,
                    date: date,
                    timeslotBookings: store.timeslotBookings
                )
            }
        }
    }

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

    private var hasBlockedDates: Bool {
        store.availabilityRecords.contains { $0.status == "blocked" }
    }

    private var hasBookedDates: Bool {
        store.availabilityRecords.contains { $0.status == "booked" }
    }

    @ViewBuilder
    private func dayBackground(for day: Date) -> some View {
        switch store.availabilityStatus(for: day) {
        case .blocked:
            Circle().fill(AppTheme.toneColor(.coral).opacity(0.18))
        case .hold:
            Circle().fill(AppTheme.toneColor(.gold).opacity(0.18))
        case .booked:
            Circle().fill(AppTheme.toneColor(.coral).opacity(0.10))
        case nil:
            Color.clear
        }
    }

    private func dayTextColor(for day: Date) -> Color {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: .now)
        guard normalizedDate >= today else { return AppTheme.Palette.subdued }

        switch store.availabilityStatus(for: day) {
        case .blocked:
            return AppTheme.toneColor(.coral)
        case .hold:
            return AppTheme.toneColor(.gold)
        case .booked:
            return AppTheme.Palette.subdued
        case nil:
            if store.draft.weeklySchedule.isAvailable(on: day) {
                return AppTheme.Palette.textPrimary
            }
            return AppTheme.Palette.textSecondary
        }
    }

    private func dayOpacity(for day: Date) -> Double {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: .now)
        guard normalizedDate >= today else { return 0.45 }

        if store.availabilityStatus(for: day) != nil {
            return 1
        }

        if store.draft.weeklySchedule.isAvailable(on: day) {
            return 1
        }

        return 0.7
    }

    private func accessibilityLabel(for day: Date) -> String {
        let dateLabel = day.formatted(date: .abbreviated, time: .omitted)
        let statusLabel: String

        switch store.availabilityStatus(for: day) {
        case .blocked:
            statusLabel = "Blocked"
        case .hold:
            statusLabel = "Hold"
        case .booked:
            statusLabel = "Booked"
        case nil:
            if store.isDateAvailableBySchedule(day) {
                statusLabel = "Open"
            } else {
                statusLabel = "Unavailable"
            }
        }

        return "\(dateLabel), \(statusLabel)"
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

    private func updateAvailability(for day: Date) {
        lastTappedDate = day
        if store.draft.timeslotsEnabled {
            timeslotOverrideDate = day
        } else {
            Task {
                await store.cycleAvailability(on: day)
            }
        }
    }

    private func previousMonth() {
        visibleMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: visibleMonthStart) ?? visibleMonthStart
    }

    private func nextMonth() {
        visibleMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonthStart) ?? visibleMonthStart
    }
}
