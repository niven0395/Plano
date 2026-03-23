import Foundation

nonisolated enum CurrencyValueFormatter {
    static func cents(from value: String?) -> Int? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased().replacingOccurrences(of: ",", with: "")
        let multiplier: Double = normalized.contains("k") ? 1_000 : 1
        let numericCharacters = normalized.filter { $0.isNumber || $0 == "." }

        guard let numericValue = Double(numericCharacters), numericValue > 0 else { return nil }
        return Int((numericValue * multiplier * 100).rounded())
    }

    static func label(forCents cents: Int, currencyCode: String = "CAD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "$0"
    }
}

nonisolated struct CurrencyInputValue: Hashable, Sendable {
    var dollars: String = ""
    var cents: String = ""

    init(dollars: String = "", cents: String = "") {
        self.dollars = dollars
        self.cents = cents
    }

    init(totalCents: Int) {
        let normalized = max(totalCents, 0)
        dollars = String(normalized / 100)
        cents = String(format: "%02d", normalized % 100)
    }

    var totalCents: Int? {
        let dollarDigits = dollars.filter(\.isNumber)
        let centDigits = cents.filter(\.isNumber)

        guard !dollarDigits.isEmpty || !centDigits.isEmpty else { return nil }
        guard let dollarValue = Int(dollarDigits.isEmpty ? "0" : dollarDigits) else { return nil }

        let normalizedCentText: String
        switch centDigits.count {
        case 0:
            normalizedCentText = "00"
        case 1:
            normalizedCentText = "0\(centDigits)"
        default:
            normalizedCentText = String(centDigits.prefix(2))
        }

        guard let centValue = Int(normalizedCentText) else { return nil }
        return (dollarValue * 100) + centValue
    }

    mutating func apply(totalCents: Int?) {
        guard let totalCents, totalCents > 0 else {
            dollars = ""
            cents = ""
            return
        }

        let normalized = CurrencyInputValue(totalCents: totalCents)
        dollars = normalized.dollars
        cents = normalized.cents
    }
}
