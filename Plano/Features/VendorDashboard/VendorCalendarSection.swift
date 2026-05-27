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

    private var isViewingCurrentMonth: Bool {
        Calendar.current.isDate(visibleMonthStart, equalTo: .now, toGranularity: .month)
    }

    private var monthSummary: MonthSummaryCounts {
        let monthRange = Calendar.current.dateInterval(of: .month, for: visibleMonthStart)
        var confirmed = 0
        var pending = 0
        var blocked = 0

        for (date, entry) in bookingsByDate {
            guard let range = monthRange, range.contains(date) else { continue }
            if entry.hasConfirmed { confirmed += entry.bookings.filter { $0.kind == .confirmed }.count }
            if entry.hasPending { pending += entry.bookings.filter { $0.kind == .pending }.count }
        }

        for blockedDate in blockedDates {
            guard let range = monthRange, range.contains(blockedDate) else { continue }
            blocked += 1
        }

        return MonthSummaryCounts(confirmed: confirmed, pending: pending, blocked: blocked)
    }

    var body: some View {
        AppSurface {
            VStack(spacing: 16) {
                monthHeader

                if monthSummary.isEmpty == false {
                    SignalRow(items: [
                        monthSummary.confirmed > 0
                            ? .text("\(monthSummary.confirmed) confirmed", symbolName: "checkmark.circle.fill")
                            : nil,
                        monthSummary.pending > 0
                            ? .text("\(monthSummary.pending) pending", symbolName: "clock.fill")
                            : nil,
                        monthSummary.blocked > 0
                            ? .text("\(monthSummary.blocked) blocked", symbolName: "xmark.circle.fill")
                            : nil,
                    ])
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                    spacing: 6
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
                                bookingCount: entry?.bookings.count ?? 0,
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

    private var monthHeader: some View {
        HStack(spacing: 8) {
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

            if !isViewingCurrentMonth {
                Button("Today") {
                    withAnimation(.snappy) {
                        visibleMonthStart = Calendar.current.startOfDay(for: .now)
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.Palette.chipFill, in: Capsule())
                .overlay { Capsule().stroke(AppTheme.Palette.border, lineWidth: 1) }
                .transition(.opacity.combined(with: .scale))
            }

            Spacer()

            Button("Next month", systemImage: "chevron.right") {
                visibleMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonthStart) ?? visibleMonthStart
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Palette.textPrimary)
        }
        .animation(.snappy, value: isViewingCurrentMonth)
    }
}

// MARK: - VendorCalendarDayCell

private struct VendorCalendarDayCell: View {
    let day: Date
    let hasConfirmed: Bool
    let hasPending: Bool
    let isBlocked: Bool
    let bookingCount: Int
    let isToday: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    private let cornerRadius: CGFloat = 10

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                // Background wash: selected > blocked > confirmed+pending > confirmed > pending > none
                backgroundFill
                    .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))

                // Blocked non-color safety cue — SF Symbol overlay
                if isBlocked && !isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.coral))
                        .symbolRenderingMode(.hierarchical)
                        .padding(4)
                }

                VStack(spacing: 2) {
                    Text(day.formatted(.dateTime.day()))
                        .font(.subheadline.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(dayNumberStyle)

                    // Today dot (only when today and no selection fill)
                    if isToday && !isSelected {
                        Circle()
                            .fill(AppTheme.Palette.accent)
                            .frame(width: 3, height: 3)
                            .accessibilityHidden(true)
                    } else {
                        // Reserve the 3pt slot so cells with/without the dot line up
                        Color.clear.frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)

                // Count pill for multi-booking days
                if bookingCount >= 2, !isSelected {
                    Text("\(bookingCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(countPillForeground)
                        .frame(minWidth: 16, minHeight: 16)
                        .padding(.horizontal, 4)
                        .background(countPillBackground, in: Capsule())
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var backgroundFill: some View {
        if isSelected {
            Rectangle().fill(AppTheme.Palette.accent)
        } else if isBlocked {
            Rectangle().fill(AppTheme.toneBackground(.coral))
        } else if hasConfirmed && hasPending {
            LinearGradient(
                colors: [AppTheme.toneBackground(.sage), AppTheme.toneBackground(.gold)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if hasConfirmed {
            Rectangle().fill(AppTheme.toneBackground(.sage))
        } else if hasPending {
            Rectangle().fill(AppTheme.toneBackground(.gold))
        } else {
            Rectangle().fill(Color.clear)
        }
    }

    private var dayNumberStyle: Color {
        if isSelected { return AppTheme.Palette.accentForeground }
        if isToday { return AppTheme.Palette.accent }
        return AppTheme.Palette.textPrimary
    }

    private var countPillForeground: Color {
        if hasConfirmed && hasPending { return AppTheme.toneColor(.sage) }
        if hasConfirmed { return AppTheme.toneColor(.sage) }
        if hasPending { return AppTheme.toneColor(.gold) }
        if isBlocked { return AppTheme.toneColor(.coral) }
        return AppTheme.Palette.textSecondary
    }

    private var countPillBackground: Color {
        AppTheme.Palette.elevatedSurface
    }

    private var accessibilityLabel: String {
        let dateLabel = day.formatted(date: .abbreviated, time: .omitted)
        var parts = [dateLabel]
        if bookingCount >= 2 {
            parts.append("\(bookingCount) bookings")
        } else if hasConfirmed {
            parts.append("confirmed booking")
        } else if hasPending {
            parts.append("pending booking")
        }
        if isBlocked { parts.append("blocked") }
        if isToday { parts.append("today") }
        if isSelected { parts.append("selected") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Month summary helper

private struct MonthSummaryCounts {
    let confirmed: Int
    let pending: Int
    let blocked: Int

    var isEmpty: Bool { confirmed == 0 && pending == 0 && blocked == 0 }
}

// MARK: - VendorCalendarDateDetailView

private struct VendorCalendarDateDetailView: View {
    let date: Date
    let entry: VendorCalendarDayEntry?
    let isBlocked: Bool
    let onToggleBlock: () -> Void

    private var bookingCount: Int { entry?.bookings.count ?? 0 }
    private var confirmedCount: Int { entry?.bookings.filter { $0.kind == .confirmed }.count ?? 0 }
    private var pendingCount: Int { entry?.bookings.filter { $0.kind == .pending }.count ?? 0 }

    private var isPastDate: Bool {
        date < Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer(minLength: 8)

                    if !isPastDate {
                        toggleBlockButton
                    }
                }

                if isBlocked && bookingCount == 0 {
                    Label("Date is blocked for new bookings", systemImage: "xmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.toneColor(.coral))
                        .symbolRenderingMode(.hierarchical)
                } else if let entry, !entry.bookings.isEmpty {
                    if bookingCount >= 2 {
                        Text(bookingSummaryText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    VStack(spacing: 0) {
                        ForEach(entry.bookings) { booking in
                            VendorCalendarBookingRow(booking: booking)

                            if booking.id != entry.bookings.last?.id {
                                Divider()
                            }
                        }
                    }
                } else {
                    Text("No bookings on this date.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var toggleBlockButton: some View {
        if isBlocked {
            Button(action: onToggleBlock) {
                Label("Unblock", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(CalendarCapsuleButtonStyle(tone: .accent))
            .accessibilityLabel("Unblock this date")
        } else {
            Button(action: onToggleBlock) {
                Label("Block", systemImage: "xmark.circle")
            }
            .buttonStyle(CalendarCapsuleButtonStyle(tone: .coral))
            .accessibilityLabel("Block this date")
        }
    }

    private var bookingSummaryText: String {
        var parts: [String] = []
        if confirmedCount > 0 { parts.append("\(confirmedCount) confirmed") }
        if pendingCount > 0 { parts.append("\(pendingCount) pending") }
        let pieces = parts.joined(separator: ", ")
        return "\(bookingCount) bookings — \(pieces)"
    }
}

private struct CalendarCapsuleButtonStyle: ButtonStyle {
    enum Tone { case accent, coral }
    let tone: Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(background, in: Capsule())
            .overlay {
                Capsule().stroke(borderColor, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }

    private var foreground: Color {
        switch tone {
        case .accent: AppTheme.Palette.accent
        case .coral: AppTheme.toneColor(.coral)
        }
    }

    private var background: Color {
        switch tone {
        case .accent: AppTheme.Palette.chipFill
        case .coral: AppTheme.toneBackground(.coral)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .accent: AppTheme.Palette.border
        case .coral: AppTheme.toneColor(.coral).opacity(0.25)
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
        HStack(spacing: 8) {
            legendChip(title: "Confirmed", symbolName: "checkmark.circle.fill", tone: .sage)
            legendChip(title: "Pending", symbolName: "clock.fill", tone: .gold)
            if hasBlocked {
                legendChip(title: "Blocked", symbolName: "xmark.circle.fill", tone: .coral)
            }
            Spacer(minLength: 0)
        }
    }

    private func legendChip(title: String, symbolName: String, tone: AccentTone) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.toneColor(tone))
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.toneColor(tone))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(AppTheme.toneBackground(tone), in: Capsule())
        .overlay {
            Capsule().stroke(AppTheme.toneColor(tone).opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
