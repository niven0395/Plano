import SwiftUI

struct SchedulingModeEditor: View {
    let store: VendorProfileEditStore

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scheduling")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(store.draft.schedulingMode.description)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            Picker("Scheduling mode", selection: $store.draft.schedulingMode) {
                ForEach(SchedulingMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .hapticFeedback(.selection, trigger: store.draft.schedulingMode)

            switch store.draft.schedulingMode {
            case .calendar:
                EmptyView()
            case .timeslots:
                durationSection
                dailyHoursSection
                bufferSection
                rollingWindowSection
                timezoneSection
                slotPreviewSection
            case .eventTimeRange:
                eventTimeRangeSection
            }
        }
    }

    // MARK: - Event Time Range

    private var eventTimeRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accepted event hours")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text("Hosts can request events within this time window.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Earliest")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    DatePicker(
                        "Earliest time",
                        selection: startTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    DatePicker(
                        "Latest time",
                        selection: endTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                Spacer()
            }
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appointment duration")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(TimeslotConfig.allowedDurations, id: \.self) { duration in
                        Button {
                            store.draft.timeslotDurationMinutes = duration
                        } label: {
                            FilterChip(
                                title: durationLabel(for: duration),
                                isSelected: store.draft.timeslotDurationMinutes == duration
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .hapticFeedback(.selection, trigger: store.draft.timeslotDurationMinutes)
    }

    // MARK: - Daily Hours

    private var dailyHoursSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily hours")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    DatePicker(
                        "Start time",
                        selection: startTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("End")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    DatePicker(
                        "End time",
                        selection: endTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                Spacer()
            }
        }
    }

    // MARK: - Buffer

    private var bufferSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Buffer between slots")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(TimeslotConfig.allowedBuffers, id: \.self) { buffer in
                        Button {
                            store.draft.timeslotBufferMinutes = buffer
                        } label: {
                            FilterChip(
                                title: bufferLabel(for: buffer),
                                isSelected: store.draft.timeslotBufferMinutes == buffer
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .hapticFeedback(.selection, trigger: store.draft.timeslotBufferMinutes)
    }

    // MARK: - Rolling Window

    private var rollingWindowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How far ahead hosts can book")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(rollingWindowOptions, id: \.days) { option in
                        Button {
                            store.draft.timeslotRollingWindowDays = option.days
                        } label: {
                            FilterChip(
                                title: option.label,
                                isSelected: store.draft.timeslotRollingWindowDays == option.days
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .hapticFeedback(.selection, trigger: store.draft.timeslotRollingWindowDays)
    }

    // MARK: - Timezone

    private var timezoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timezone")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            NavigationLink {
                TimezonePickerView(selectedTimezone: Binding(
                    get: { store.draft.timeslotTimezone },
                    set: { store.draft.timeslotTimezone = $0 }
                ))
            } label: {
                HStack {
                    Text(store.draft.timeslotTimezone.replacingOccurrences(of: "_", with: " "))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: AppTheme.compactCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.compactCornerRadius)
                        .stroke(AppTheme.Palette.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Slot Preview

    private var slotPreviewSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

            Text(store.draft.timeslotConfig.slotPreviewLabel)
                .font(.footnote)
                .foregroundStyle(AppTheme.Palette.subdued)
        }
    }

    // MARK: - Time Bindings

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(
                    hour: store.draft.timeslotStartHour,
                    minute: store.draft.timeslotStartMinute
                )) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                store.draft.timeslotStartHour = components.hour ?? 9
                store.draft.timeslotStartMinute = components.minute ?? 0
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(
                    hour: store.draft.timeslotEndHour,
                    minute: store.draft.timeslotEndMinute
                )) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                store.draft.timeslotEndHour = components.hour ?? 17
                store.draft.timeslotEndMinute = components.minute ?? 0
            }
        )
    }

    // MARK: - Labels

    private func durationLabel(for minutes: Int) -> String {
        switch minutes {
        case 15: "15 min"
        case 30: "30 min"
        case 45: "45 min"
        case 60: "1 hr"
        case 90: "1.5 hr"
        case 120: "2 hr"
        default: "\(minutes) min"
        }
    }

    private func bufferLabel(for minutes: Int) -> String {
        minutes == 0 ? "None" : "\(minutes) min"
    }

    private var rollingWindowOptions: [(days: Int, label: String)] {
        [
            (7, "1 week"),
            (14, "2 weeks"),
            (21, "3 weeks"),
            (30, "1 month"),
            (60, "2 months"),
            (90, "3 months"),
        ]
    }
}

// MARK: - Timezone Picker

private struct TimezonePickerView: View {
    @Binding var selectedTimezone: String
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(filteredTimezones, id: \.self) { identifier in
                Button {
                    selectedTimezone = identifier
                    dismiss()
                } label: {
                    HStack {
                        Text(identifier.replacingOccurrences(of: "_", with: " "))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Spacer()

                        if identifier == selectedTimezone {
                            Image(systemName: "checkmark")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search timezones")
        .navigationTitle("Timezone")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredTimezones: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers
        guard !searchText.isEmpty else { return all }
        let query = searchText.lowercased()
        return all.filter { $0.lowercased().contains(query) }
    }
}
