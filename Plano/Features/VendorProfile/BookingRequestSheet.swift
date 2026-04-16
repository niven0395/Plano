import SwiftUI

struct BookingRequestSheet: View {
    let vendorName: String
    let selectedDate: Date
    let selectedTimeslot: TimeslotOption?
    let requestedStartTime: Date?
    let requestedEndTime: Date?
    @Binding var note: String
    let showsGuestCount: Bool
    @Binding var guestCountLabel: String
    let intakeQuestions: [LeadIntakeQuestion]
    @Binding var intakeAnswers: [LeadIntakeAnswer]
    let isSubmitting: Bool
    let bookingSubmittedSuccessfully: Bool
    let hasValidTimeRange: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    private static let guestCountOptions = [
        "Under 20", "20–50", "50–100", "100–150", "150–200", "200+"
    ]

    private var hasIntakeQuestions: Bool {
        !intakeQuestions.isEmpty
    }

    private var requiredQuestionsAnswered: Bool {
        let required = intakeQuestions.filter(\.isRequired)
        guard !required.isEmpty else { return true }
        return required.allSatisfy { question in
            intakeAnswers.first(where: { $0.questionID == question.id })?.hasValue ?? false
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Vendor", value: vendorName)
                    LabeledContent("Date") {
                        Text(selectedDate, format: .dateTime.month(.wide).day().year())
                    }
                    if let timeslot = selectedTimeslot {
                        LabeledContent("Time") {
                            Text(timeslot.timeRangeLabel)
                        }
                    }
                    if let start = requestedStartTime, let end = requestedEndTime {
                        LabeledContent("Event time") {
                            Text("\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                        }
                    }
                }

                if showsGuestCount {
                    Section("Guest count") {
                        FlowLayout(spacing: 8) {
                            ForEach(Self.guestCountOptions, id: \.self) { option in
                                Button {
                                    guestCountLabel = guestCountLabel == option ? "" : option
                                } label: {
                                    Text(option)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(guestCountLabel == option ? .white : AppTheme.Palette.textPrimary)
                                        .background(
                                            guestCountLabel == option ? AppTheme.Palette.accent : AppTheme.Palette.elevatedSurface,
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if hasIntakeQuestions {
                    Section("A few questions from the vendor") {
                        LeadIntakeFormView(
                            questions: intakeQuestions,
                            answers: $intakeAnswers
                        )
                    }
                }

                Section("Note (optional)") {
                    TextField("Anything else the vendor should know...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if requestedStartTime != nil || requestedEndTime != nil, !hasValidTimeRange {
                    Section {
                        Text("End time must be later than the start time.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Request Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Request", action: onSubmit)
                            .disabled(!requiredQuestionsAnswered || !hasValidTimeRange)
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .hapticFeedback(.success, trigger: bookingSubmittedSuccessfully) { old, new in
                !old && new
            }
        }
        .presentationDetents(hasIntakeQuestions ? [.medium, .large] : [.medium])
    }
}
