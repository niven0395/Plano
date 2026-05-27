import Foundation
import Testing
@testable import Plano

struct VendorPaymentRequestComposerTests {
    @Test
    func externalPaymentWithVendorEmailPrefillsETransferInstructions() {
        let note = VendorPaymentRequestComposer.suggestedNote(
            method: .eTransfer,
            amountCents: 25_000,
            vendorEmail: "payments@studio.test",
            vendorName: "Studio North"
        )

        #expect(note.contains("$250"))
        #expect(note.contains("payments@studio.test"))
        #expect(note.contains("e-transfer"))
    }

    @Test
    func cashPaymentSuggestionMentionsCashHandoff() {
        let note = VendorPaymentRequestComposer.suggestedNote(
            method: .cash,
            amountCents: 18_500,
            vendorEmail: nil,
            vendorName: "Studio North"
        )

        #expect(note.contains("$185"))
        #expect(note.contains("cash"))
        #expect(note.contains("hand"))
    }

    @Test
    func paymentMessageBodyIncludesInstructionsWhenPresent() {
        let body = VendorPaymentRequestComposer.messageBody(
            amountCents: 12_500,
            note: "Please send an e-transfer to payments@studio.test."
        )

        #expect(body.contains("Deposit of $125 requested."))
        #expect(body.contains("payments@studio.test"))
    }
}
