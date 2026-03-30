import SwiftUI

struct BookingRequestSheet: View {
    let vendorName: String
    let selectedDate: Date
    let selectedTimeslot: TimeslotOption?
    let requestedStartTime: Date?
    let requestedEndTime: Date?
    let linkedEvent: PartyEvent?
    let availableEvents: [PartyEvent]
    let onEventChanged: (PartyEvent?) -> Void
    @Binding var note: String
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

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
                    LabeledContent("Event") {
                        if availableEvents.isEmpty {
                            Text("No events")
                                .foregroundStyle(.secondary)
                        } else {
                            Menu {
                                Button {
                                    onEventChanged(nil)
                                } label: {
                                    if linkedEvent == nil {
                                        Label("No event", systemImage: "checkmark")
                                    } else {
                                        Text("No event")
                                    }
                                }
                                Divider()
                                ForEach(availableEvents) { event in
                                    Button {
                                        onEventChanged(event)
                                    } label: {
                                        if linkedEvent?.id == event.id {
                                            Label("\(event.title) · \(event.formattedDate)", systemImage: "checkmark")
                                        } else {
                                            Text("\(event.title) · \(event.formattedDate)")
                                        }
                                    }
                                }
                            } label: {
                                Text(linkedEvent?.title ?? "No event")
                                    .foregroundStyle(linkedEvent != nil ? .primary : .secondary)
                            }
                        }
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
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .hapticFeedback(.success, trigger: isSubmitting) { old, new in
                old && !new
            }
        }
        .presentationDetents([.medium])
    }
}
