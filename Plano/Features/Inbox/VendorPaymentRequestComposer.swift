import Foundation

enum VendorPaymentRequestMethod: String, CaseIterable, Identifiable {
    case platform
    case eTransfer = "e_transfer"
    case cash

    var id: Self { self }

    var title: String {
        switch self {
        case .platform:
            "Plano"
        case .eTransfer:
            "E-transfer"
        case .cash:
            "Cash"
        }
    }

    static func availableMethods(for paymentMode: PaymentMode) -> [VendorPaymentRequestMethod] {
        switch paymentMode {
        case .platform:
            [.platform]
        case .cashOnly:
            [.cash]
        case .external:
            [.eTransfer, .cash]
        }
    }
}

enum VendorPaymentRequestComposer {
    static func defaultMethod(for paymentMode: PaymentMode) -> VendorPaymentRequestMethod {
        VendorPaymentRequestMethod.availableMethods(for: paymentMode).first ?? .eTransfer
    }

    static func suggestedNote(
        method: VendorPaymentRequestMethod,
        amountCents: Int?,
        vendorEmail: String?,
        vendorName: String,
        paymentType: PaymentType = .deposit
    ) -> String {
        let amountLabel = amountCents.map { CurrencyValueFormatter.label(forCents: $0, currencyCode: "CAD") }
            ?? "the requested amount"

        let typePrefix = paymentType == .deposit ? "the deposit of" : "full payment of"

        switch method {
        case .platform:
            return "Please pay \(typePrefix) \(amountLabel) on Plano to confirm your booking with \(vendorName)."
        case .eTransfer:
            if let email = normalized(vendorEmail) {
                return "Please send an e-transfer of \(typePrefix) \(amountLabel) to \(email). Add your event name in the memo so I can match the payment."
            }

            return "Please send an e-transfer of \(typePrefix) \(amountLabel). Reply here once it has been sent so I can confirm the booking."
        case .cash:
            return "Please plan for a cash payment of \(typePrefix) \(amountLabel). Reply here to confirm when and how you'd like to hand it over."
        }
    }

    static func messageBody(amountCents: Int, note: String?, paymentType: PaymentType = .deposit, vendorEmail: String? = nil) -> String {
        let amountLabel = CurrencyValueFormatter.label(forCents: amountCents, currencyCode: "CAD")
        let header = "\(paymentType.messagePrefix) of \(amountLabel) requested."

        var lines = [header]

        if let email = normalized(vendorEmail) {
            lines.append("Vendor email: \(email)")
        }

        if let note = normalized(note) {
            lines.append(note)
        }

        return lines.joined(separator: "\n")
    }

    static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
