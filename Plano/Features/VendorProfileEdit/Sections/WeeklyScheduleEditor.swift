import SwiftUI

struct WeeklyScheduleEditor: View {
    @Binding var schedulePreset: SchedulePreset
    @Binding var availableDays: Set<Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("When are you available?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Use a preset for speed, then fine-tune individual days if your week is more specific.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            HStack(spacing: 6) {
                ForEach(SchedulePreset.allCases) { preset in
                    Button {
                        selectPreset(preset)
                    } label: {
                        FilterChip(title: preset.title, isSelected: schedulePreset == preset, expands: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                ForEach(Weekday.allCases) { weekday in
                    Button {
                        toggleDay(weekday)
                    } label: {
                        Text(String(weekday.shortName.prefix(1)))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(availableDays.contains(weekday) ? AppTheme.Palette.elevatedSurface : AppTheme.Palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                availableDays.contains(weekday)
                                    ? AnyShapeStyle(AppTheme.Palette.accent)
                                    : AnyShapeStyle(AppTheme.Palette.elevatedSurface),
                                in: Circle()
                            )
                            .overlay {
                                Circle()
                                    .stroke(
                                        availableDays.contains(weekday) ? AppTheme.Palette.accent : AppTheme.Palette.border,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(weekday.fullName)
                    .accessibilityValue(availableDays.contains(weekday) ? "Selected" : "Not selected")
                }
            }

            Text(scheduleSummary)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
        .hapticFeedback(.selection, trigger: schedulePreset)
        .hapticFeedback(.selection, trigger: availableDays)
        .animation(.snappy, value: availableDays)
        .animation(.snappy, value: schedulePreset)
    }

    private var scheduleSummary: String {
        if availableDays.isEmpty {
            return "No recurring days selected yet."
        }

        let labels = availableDays.sorted().map(\.fullName)
        return labels.joined(separator: ", ")
    }

    private func selectPreset(_ preset: SchedulePreset) {
        schedulePreset = preset

        if let presetDays = preset.availableDays {
            availableDays = presetDays
        }
    }

    private func toggleDay(_ weekday: Weekday) {
        schedulePreset = .custom

        if availableDays.contains(weekday) {
            availableDays.remove(weekday)
        } else {
            availableDays.insert(weekday)
        }
    }
}
