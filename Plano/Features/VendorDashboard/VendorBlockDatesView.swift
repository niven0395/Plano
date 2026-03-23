import SwiftUI

struct VendorBlockDatesView: View {
    @Environment(VendorProfileEditStore.self) private var store

    enum Mode: String, CaseIterable {
        case dateRange = "Date Range"
        case specificDates = "Specific Dates"
    }

    @State private var mode: Mode = .dateRange
    @State private var rangeStart: Date = Calendar.current.startOfDay(for: .now)
    @State private var rangeEnd: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDates: Set<Date> = []
    @State private var visibleMonthStart = Calendar.current.startOfDay(for: .now)
    @State private var isBlocking = false

    private var blockedRecords: [VendorAvailabilityRecord] {
        store.availabilityRecords
            .filter { $0.status == VendorAvailabilityStatus.blocked.rawValue }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    private var rangeDateCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: rangeStart)
        let end = calendar.startOfDay(for: rangeEnd)
        guard end >= start else { return 0 }
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    private var rangeDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: rangeStart)
        let end = calendar.startOfDay(for: rangeEnd)
        guard end >= start else { return [] }

        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? end.addingTimeInterval(1)
        }
        return dates
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.screenPadding)

                switch mode {
                case .dateRange:
                    dateRangeSection
                case .specificDates:
                    specificDatesSection
                }

                if !blockedRecords.isEmpty {
                    existingBlocksSection
                }
            }
            .padding(.vertical, 16)
        }
        .background { AppBackdrop() }
        .navigationTitle("Block Dates")
        .navigationBarTitleDisplayMode(.inline)
        .saveFeedback(
            outcome: store.lastSaveOutcome,
            successMessage: "Dates updated",
            onReset: { store.lastSaveOutcome = .idle }
        )
        .task {
            await store.loadIfNeeded()
        }
    }

    // MARK: - Date Range

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSurface {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker(
                        "Start date",
                        selection: $rangeStart,
                        in: Calendar.current.startOfDay(for: .now)...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(.subheadline.weight(.medium))

                    DatePicker(
                        "End date",
                        selection: $rangeEnd,
                        in: rangeStart...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)

            if rangeDateCount > 0 {
                Text("Blocking \(rangeDateCount) date\(rangeDateCount == 1 ? "" : "s") from \(rangeStart.formatted(date: .abbreviated, time: .omitted)) to \(rangeEnd.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .padding(.horizontal, AppTheme.screenPadding)
            }

            Button {
                Task {
                    isBlocking = true
                    await store.blockDates(rangeDates)
                    isBlocking = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isBlocking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Block Range")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.toneColor(.coral), in: .rect(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .disabled(rangeDateCount == 0 || isBlocking)
            .opacity(rangeDateCount == 0 ? 0.5 : 1)
            .padding(.horizontal, AppTheme.screenPadding)
        }
    }

    // MARK: - Specific Dates

    private var specificDatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSurface {
                VStack(spacing: 16) {
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
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(calendarDays.indices, id: \.self) { index in
                            if let day = calendarDays[index] {
                                let normalized = Calendar.current.startOfDay(for: day)
                                let isBlocked = store.availabilityStatus(for: normalized) == .blocked
                                let isSelected = selectedDates.contains(normalized)
                                let isPast = normalized < Calendar.current.startOfDay(for: .now)
                                let isBooked = store.availabilityStatus(for: normalized) == .booked

                                Button {
                                    toggleDate(normalized)
                                } label: {
                                    Text(day.formatted(.dateTime.day()))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(dayTextColor(isPast: isPast, isBlocked: isBlocked, isSelected: isSelected, isBooked: isBooked))
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .background {
                                            if isSelected {
                                                Circle().fill(AppTheme.Palette.accent.opacity(0.2))
                                            } else if isBlocked {
                                                Circle().fill(AppTheme.toneColor(.coral).opacity(0.18))
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .disabled(isPast || isBooked)
                            } else {
                                Color.clear
                                    .frame(height: 36)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)

            if !selectedDates.isEmpty {
                Text("\(selectedDates.count) date\(selectedDates.count == 1 ? "" : "s") selected")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .padding(.horizontal, AppTheme.screenPadding)
            }

            Button {
                Task {
                    isBlocking = true
                    await store.blockDates(Array(selectedDates))
                    selectedDates.removeAll()
                    isBlocking = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isBlocking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Block Selected")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.toneColor(.coral), in: .rect(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .disabled(selectedDates.isEmpty || isBlocking)
            .opacity(selectedDates.isEmpty ? 0.5 : 1)
            .padding(.horizontal, AppTheme.screenPadding)
        }
    }

    // MARK: - Existing Blocks

    private var existingBlocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Blocked Dates")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .padding(.horizontal, AppTheme.screenPadding)

            AppSurface {
                VStack(spacing: 0) {
                    let grouped = groupedBlockedRecords
                    ForEach(Array(grouped.keys.sorted()), id: \.self) { monthKey in
                        if let records = grouped[monthKey] {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(monthKey)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.subdued)
                                    .padding(.vertical, 8)

                                ForEach(records) { record in
                                    HStack {
                                        if let date = record.date {
                                            Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(AppTheme.Palette.textPrimary)
                                        }

                                        Spacer()

                                        Button("Unblock") {
                                            if let date = record.date {
                                                Task {
                                                    await store.unblockDates([date])
                                                }
                                            }
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.Palette.accent)
                                    }
                                    .padding(.vertical, 10)

                                    if record.id != records.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
        }
    }

    // MARK: - Calendar Helpers

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

    private var groupedBlockedRecords: [String: [VendorAvailabilityRecord]] {
        var grouped: [String: [VendorAvailabilityRecord]] = [:]
        for record in blockedRecords {
            guard let date = record.date else { continue }
            let key = date.formatted(.dateTime.month(.wide).year())
            grouped[key, default: []].append(record)
        }
        return grouped
    }

    private func toggleDate(_ date: Date) {
        if selectedDates.contains(date) {
            selectedDates.remove(date)
        } else {
            selectedDates.insert(date)
        }
    }

    private func dayTextColor(isPast: Bool, isBlocked: Bool, isSelected: Bool, isBooked: Bool) -> Color {
        if isPast || isBooked { return AppTheme.Palette.subdued }
        if isBlocked { return AppTheme.toneColor(.coral) }
        if isSelected { return AppTheme.Palette.accent }
        return AppTheme.Palette.textPrimary
    }

    private func previousMonth() {
        visibleMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: visibleMonthStart) ?? visibleMonthStart
    }

    private func nextMonth() {
        visibleMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonthStart) ?? visibleMonthStart
    }
}
