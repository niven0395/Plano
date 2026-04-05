import SwiftUI

// MARK: - Display Models

struct VendorCalendarBooking: Identifiable, Hashable {
    let id: UUID
    let hostName: String
    let title: String
    let stage: BookingStage
    let kind: Kind

    enum Kind: Hashable {
        case confirmed
        case pending
    }
}

struct VendorCalendarDayEntry {
    let date: Date
    let bookings: [VendorCalendarBooking]

    var hasConfirmed: Bool {
        bookings.contains { $0.kind == .confirmed }
    }

    var hasPending: Bool {
        bookings.contains { $0.kind == .pending }
    }
}

// MARK: - VendorCalendarSection

struct VendorCalendarSection: View {
    let inboxStore: InboxStore

    @Environment(VendorProfileEditStore.self) private var editStore
    @Environment(AppRouter.self) private var router
    @State private var visibleMonthStart = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate: Date?

    private var bookingsByDate: [Date: VendorCalendarDayEntry] {
        let calendar = Calendar.current
        var map: [Date: [VendorCalendarBooking]] = [:]

        let pendingStages: Set<BookingStage> = [.requested, .accepted, .paymentRequested]

        for thread in inboxStore.vendorScopedConversations() {
            guard thread.stage == .paid || pendingStages.contains(thread.stage) else { continue }
            guard let eventDate = thread.resolvedEventDate else { continue }

            let normalizedDate = calendar.startOfDay(for: eventDate)
            let kind: VendorCalendarBooking.Kind = thread.stage == .paid ? .confirmed : .pending

            let booking = VendorCalendarBooking(
                id: thread.id,
                hostName: thread.hostName,
                title: thread.eventTitle,
                stage: thread.stage,
                kind: kind
            )

            map[normalizedDate, default: []].append(booking)
        }

        var entries: [Date: VendorCalendarDayEntry] = [:]
        for (date, bookings) in map {
            entries[date] = VendorCalendarDayEntry(date: date, bookings: bookings)
        }
        return entries
    }

    private var blockedDates: Set<Date> {
        let calendar = Calendar.current
        return Set(
            editStore.availabilityRecords
                .filter { $0.status == VendorAvailabilityStatus.blocked.rawValue }
                .compactMap { $0.date }
                .map { calendar.startOfDay(for: $0) }
        )
    }

    private var selectedDateEntry: VendorCalendarDayEntry? {
        guard let selectedDate else { return nil }
        let key = Calendar.current.startOfDay(for: selectedDate)
        return bookingsByDate[key]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(
                    title: "Calendar",
                    subtitle: "Your month at a glance."
                )

                Spacer(minLength: 12)

                NavigationLink(value: DiscoveryRoute.vendorAvailability) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                        Text("Manage")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.accent)
                }
                .buttonStyle(.plain)
            }

            VendorCalendarGrid(
                visibleMonthStart: $visibleMonthStart,
                selectedDate: $selectedDate,
                bookingsByDate: bookingsByDate,
                blockedDates: blockedDates
            )

            VendorCalendarLegend(hasBlocked: !blockedDates.isEmpty)

            if let selectedDate {
                let key = Calendar.current.startOfDay(for: selectedDate)
                let isBlocked = blockedDates.contains(key)
                VendorCalendarDateDetailView(
                    date: key,
                    entry: selectedDateEntry,
                    isBlocked: isBlocked,
                    onToggleBlock: {
                        Task {
                            await editStore.cycleAvailability(on: key)
                        }
                    }
                )
            }
        }
        .task {
            await editStore.loadIfNeeded()
        }
    }
}

// MARK: - VendorCalendarGrid

private struct VendorCalendarGrid: View {
    @Binding var visibleMonthStart: Date
    @Binding var selectedDate: Date?
    let bookingsByDate: [Date: VendorCalendarDayEntry]
    let blockedDates: Set<Date>

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

    var body: some View {
        AppSurface {
            VStack(spacing: 16) {
                HStack {
                    Button("Previous month", systemImage: "chevron.left") {
                        visibleMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: visibleMonthStart) ?? visibleMonthStart
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Text(visibleMonthStart.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Button("Next month", systemImage: "chevron.right") {
                        visibleMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonthStart) ?? visibleMonthStart
                    }
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
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(calendarDays.indices, id: \.self) { index in
                        if let day = calendarDays[index] {
                            let normalized = Calendar.current.startOfDay(for: day)
                            let entry = bookingsByDate[normalized]
                            VendorCalendarDayCell(
                                day: day,
                                hasConfirmed: entry?.hasConfirmed ?? false,
                                hasPending: entry?.hasPending ?? false,
                                isBlocked: blockedDates.contains(normalized),
                                isToday: Calendar.current.isDateInToday(day),
                                isSelected: selectedDate.map { Calendar.current.isDate(day, inSameDayAs: $0) } ?? false,
                                onSelect: { selectedDate = normalized }
                            )
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - VendorCalendarDayCell

private struct VendorCalendarDayCell: View {
    let day: Date
    let hasConfirmed: Bool
    let hasPending: Bool
    let isBlocked: Bool
    let isToday: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.day()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isToday ? AppTheme.Palette.accent : AppTheme.Palette.textPrimary)

                HStack(spacing: 3) {
                    if hasConfirmed {
                        Circle()
                            .fill(AppTheme.toneColor(.sage))
                            .frame(width: 5, height: 5)
                    }
                    if hasPending {
                        Circle()
                            .fill(AppTheme.toneColor(.gold))
                            .frame(width: 5, height: 5)
                    }
                    if isBlocked {
                        Circle()
                            .fill(AppTheme.toneColor(.coral))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                isSelected
                    ? AppTheme.toneBackground(.blue)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.Palette.accent.opacity(0.3), lineWidth: 1)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.Palette.accent, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let dateLabel = day.formatted(date: .abbreviated, time: .omitted)
        var parts = [dateLabel]
        if hasConfirmed { parts.append("confirmed bookings") }
        if hasPending { parts.append("pending bookings") }
        if isBlocked { parts.append("blocked") }
        if isToday { parts.append("today") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - VendorCalendarDateDetailView

private struct VendorCalendarDateDetailView: View {
    let date: Date
    let entry: VendorCalendarDayEntry?
    let isBlocked: Bool
    let onToggleBlock: () -> Void

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                if isBlocked && (entry?.bookings.isEmpty ?? true) {
                    HStack {
                        Label("Blocked", systemImage: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.toneColor(.coral))

                        Spacer()

                        Button("Unblock", action: onToggleBlock)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.accent)
                    }
                } else if let entry, !entry.bookings.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(entry.bookings) { booking in
                            VendorCalendarBookingRow(booking: booking)

                            if booking.id != entry.bookings.last?.id {
                                Divider()
                            }
                        }
                    }

                    if isBlocked {
                        Button("Unblock Date", action: onToggleBlock)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.accent)
                    }
                } else {
                    HStack {
                        Text("No bookings on this date.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)

                        Spacer()

                        if date >= Calendar.current.startOfDay(for: .now) {
                            Button("Block", action: onToggleBlock)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.toneColor(.coral))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - VendorCalendarBookingRow

private struct VendorCalendarBookingRow: View {
    let booking: VendorCalendarBooking

    var body: some View {
        NavigationLink(value: DiscoveryRoute.vendorLead(
            BookingRequestSummary(
                id: booking.id,
                conversationID: booking.id,
                counterpartName: booking.hostName,
                title: booking.title,
                dateLabel: "",
                detail: "",
                amountLabel: "",
                stage: booking.stage
            )
        )) {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(booking.kind == .confirmed
                      ? AppTheme.toneColor(.sage)
                      : AppTheme.toneColor(.gold))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(booking.hostName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(booking.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(booking.hostName), \(booking.title), \(booking.kind == .confirmed ? "confirmed" : "pending")")
    }
}

// MARK: - VendorCalendarLegend

private struct VendorCalendarLegend: View {
    let hasBlocked: Bool

    var body: some View {
        HStack(spacing: 14) {
            legendItem(title: "Confirmed", color: AppTheme.toneColor(.sage))
            legendItem(title: "Pending", color: AppTheme.toneColor(.gold))
            if hasBlocked {
                legendItem(title: "Blocked", color: AppTheme.toneColor(.coral))
            }
        }
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
    }
}
