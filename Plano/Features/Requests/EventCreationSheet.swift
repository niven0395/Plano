import SwiftUI

struct EventCreationSheet: View {
    @Environment(HostPlanningStore.self) private var planner
    @Environment(\.dismiss) private var dismiss

    @State private var draft = EventDraft()
    @State private var isCreating = false
    @State private var createOutcome: SaveOutcome = .idle

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppSurface(style: .highlighted) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(
                                title: "New event",
                                subtitle: "Add the basics so search, pricing, and vendor suggestions match your brief."
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

                            fieldLabel("Event date")

                            DatePicker("Event date", selection: $draft.date, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()

                            fieldLabel("Guest count")

                            HStack(spacing: 12) {
                                TextField("50", value: $draft.guestCount, format: .number)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)
                                    .keyboardType(.numberPad)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: AppTheme.smallCornerRadius))

                                Text("guests")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.subdued)

                                Spacer()
                            }

                            fieldLabel("Budget")

                            Menu {
                                Picker("Budget", selection: $draft.budgetLabel) {
                                    ForEach(budgetOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                            } label: {
                                MenuDropdownRow(title: draft.budgetLabel)
                            }
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
            }
        }
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

    private var budgetOptions: [String] {
        [
            "$1k - $3k",
            "$3k - $5k",
            "$4k - $8k",
            "$7k - $11k",
            "$10k - $15k",
            "$15k - $25k",
            "$25k+",
        ]
    }
}
