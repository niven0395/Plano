import SwiftUI

struct BookingRequestSheet: View {
    let vendorName: String
    let selectedDate: Date
    let selectedTimeslot: TimeslotOption?
    let requestedStartTime: Date?
    let requestedEndTime: Date?
    @Binding var note: String
    let intakeQuestions: [LeadIntakeQuestion]
    @Binding var intakeAnswers: [LeadIntakeAnswer]
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

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

                if hasIntakeQuestions {
                    Section("A few questions from the vendor") {
                        LeadIntakeFormView(
                            questions: intakeQuestions,
                            answers: $intakeAnswers
                        )
                    }
                }

                Section("Note (optional)") {
                    TextField("Any details for the vendor...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
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
                            .disabled(!requiredQuestionsAnswered)
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .hapticFeedback(.success, trigger: isSubmitting) { old, new in
                old && !new
            }
        }
        .presentationDetents(hasIntakeQuestions ? [.medium, .large] : [.medium])
    }
}
