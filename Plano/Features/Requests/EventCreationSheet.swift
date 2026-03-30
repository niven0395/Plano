import SwiftUI

struct EventCreationSheet: View {
    @Environment(HostPlanningStore.self) private var planner
    @Environment(\.dismiss) private var dismiss

    @State private var draft = EventDraft()
    @State private var isCreating = false
    @State private var createOutcome: SaveOutcome = .idle
    @State private var showTimes = false
    @FocusState private var focusedField: Field?

    private enum Field { case eventName, guestCount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppSurface(style: .highlighted) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(
                                title: "New event",
                                subtitle: "Add the basics so vendors can understand your event at a glance."
                            )
                        }
                    }

                    AppSurface {
                        VStack(alignment: .leading, spacing: 18) {
                            fieldLabel("Event type")

                            Menu {
                                Picker("Event type", selection: $draft.type) {
                                    ForEach(EventType.allCases) { type in
                                        Text(type.title).tag(type)
                                    }
                                }
                            } label: {
                                MenuDropdownRow(title: draft.type.title)
                            }

                            fieldLabel("Event name")

                            TextField(draft.type.title, text: $draft.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .eventName)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .guestCount }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: AppTheme.smallCornerRadius))

                            Text("Optional — defaults to the event type if left blank.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Palette.subdued)

                            fieldLabel("City")

                            Menu {
                                Picker("City", selection: $draft.city) {
                                    ForEach(GTACity.allCases) { city in
                                        Text(city.title).tag(city.rawValue)
                                    }
                                }
                            } label: {
                                MenuDropdownRow(title: draft.city)
                            }

                            fieldLabel("Venue")

                            TextField("My home, venue name, or leave blank", text: $draft.venue)
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                                .textInputAutocapitalization(.words)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: AppTheme.smallCornerRadius))

                            Text("Optional — defaults to \"Venue TBD\" if left blank.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Palette.subdued)

                            fieldLabel("Event date")

                            DatePicker("Event date", selection: $draft.date, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()

                            timeSection

                            fieldLabel("Guest count")

                            HStack(spacing: 12) {
                                TextField("50", value: $draft.guestCount, format: .number)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)
                                    .keyboardType(.numberPad)
                                    .focused($focusedField, equals: .guestCount)
                                    .submitLabel(.done)
                                    .onSubmit { focusedField = nil }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: AppTheme.smallCornerRadius))

                                Text("guests")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.subdued)

                                Spacer()
                            }

                            fieldLabel("Venue setting")

                            Picker("Venue setting", selection: $draft.venueSetting) {
                                ForEach(VenueSetting.allCases) { setting in
                                    Text(setting.title).tag(setting)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    Button(isCreating ? "Creating…" : "Create event") {
                        createEvent()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!draft.isValid || isCreating)
                }
                .padding(AppTheme.screenPadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AppBackdrop())
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .saveFeedback(outcome: createOutcome, successMessage: "Event created") {
                createOutcome = .idle
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var timeSection: some View {
        Toggle("Add event times", isOn: $showTimes.animation(AppAnimation.transition))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.Palette.textPrimary)
            .tint(AppTheme.Palette.accent)
            .onChange(of: showTimes) { _, isOn in
                if !isOn {
                    draft.startTime = nil
                    draft.endTime = nil
                }
            }

        if showTimes {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("Start time")

                DatePicker(
                    "Start time",
                    selection: startTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .onChange(of: draft.startTime) { _, newValue in
                    if newValue == nil {
                        draft.endTime = nil
                    }
                }

                fieldLabel("End time")

                DatePicker(
                    "End time",
                    selection: endTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .disabled(draft.startTime == nil)
                .opacity(draft.startTime == nil ? 0.4 : 1)

                if let duration = draft.computedDurationHours {
                    Label(EventDuration.label(hours: duration), systemImage: "clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.accent)
                }
            }
        }
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { draft.startTime ?? defaultStartTime },
            set: { draft.startTime = $0 }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { draft.endTime ?? defaultEndTime },
            set: { draft.endTime = $0 }
        )
    }

    private var defaultStartTime: Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now
    }

    private var defaultEndTime: Date {
        Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: .now) ?? .now
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Palette.subdued)
    }

    private func createEvent() {
        guard draft.isValid, !isCreating else { return }
        isCreating = true

        Task {
            let result = await planner.addEvent(from: draft)
            if result != nil {
                createOutcome = .saved
                try? await Task.sleep(for: .seconds(0.8))
            }
            dismiss()
        }
    }
}
