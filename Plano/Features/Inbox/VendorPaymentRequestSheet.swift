import SwiftUI

struct VendorPaymentRequestSheet: View {
    let vendorName: String
    let paymentMode: PaymentMode
    let vendorEmail: String?
    let onSend: (Int, String?, PaymentType) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var paymentAmountText = ""
    @State private var paymentMethod: VendorPaymentRequestMethod
    @State private var paymentNote: String
    @State private var lastSuggestedNote: String
    @State private var paymentType: PaymentType = .deposit

    init(
        vendorName: String,
        paymentMode: PaymentMode,
        vendorEmail: String?,
        onSend: @escaping (Int, String?, PaymentType) -> Void
    ) {
        self.vendorName = vendorName
        self.paymentMode = paymentMode
        self.vendorEmail = vendorEmail
        self.onSend = onSend

        let defaultMethod = VendorPaymentRequestComposer.defaultMethod(for: paymentMode)
        let defaultNote = VendorPaymentRequestComposer.suggestedNote(
            method: defaultMethod,
            amountCents: nil,
            vendorEmail: vendorEmail,
            vendorName: vendorName
        )
        _paymentMethod = State(initialValue: defaultMethod)
        _paymentNote = State(initialValue: defaultNote)
        _lastSuggestedNote = State(initialValue: defaultNote)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("Amount in dollars", text: $paymentAmountText)
                        .keyboardType(.decimalPad)
                }

                Section("Payment type") {
                    Picker("Payment type", selection: $paymentType) {
                        ForEach(PaymentType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if availableMethods.count > 1 {
                    Section("Payment method") {
                        Picker("Payment method", selection: $paymentMethod) {
                            ForEach(availableMethods) { method in
                                Text(method.title).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } else if let method = availableMethods.first {
                    Section("Payment method") {
                        LabeledContent("Method", value: method.title)
                    }
                }

                Section("Instructions") {
                    TextField("Add payment instructions", text: $paymentNote, axis: .vertical)
                        .lineLimit(4...8)

                    Text("This note is sent to the customer and kept with the booking.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }
            .navigationTitle("Request Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        guard let amountCents else { return }

                        let note = VendorPaymentRequestComposer.normalized(paymentNote) ?? suggestedNote
                        onSend(amountCents, note, paymentType)
                        dismiss()
                    }
                    .disabled(amountCents == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: paymentMethod) { _, _ in
            syncSuggestedNoteIfNeeded()
        }
        .onChange(of: paymentAmountText) { _, _ in
            syncSuggestedNoteIfNeeded()
        }
        .onChange(of: paymentType) { _, _ in
            syncSuggestedNoteIfNeeded()
        }
    }

    private var availableMethods: [VendorPaymentRequestMethod] {
        VendorPaymentRequestMethod.availableMethods(for: paymentMode)
    }

    private var amountCents: Int? {
        guard let dollars = Double(paymentAmountText), dollars > 0 else { return nil }
        return Int((dollars * 100).rounded())
    }

    private var suggestedNote: String {
        VendorPaymentRequestComposer.suggestedNote(
            method: paymentMethod,
            amountCents: amountCents,
            vendorEmail: vendorEmail,
            vendorName: vendorName,
            paymentType: paymentType
        )
    }

    private func syncSuggestedNoteIfNeeded() {
        let nextSuggestion = suggestedNote
        let currentNote = VendorPaymentRequestComposer.normalized(paymentNote)

        if currentNote == nil || currentNote == lastSuggestedNote {
            paymentNote = nextSuggestion
        }

        lastSuggestedNote = nextSuggestion
    }
}
