import Foundation

nonisolated struct VendorSearchRequest: Hashable, Sendable {
    let text: String
    let category: VendorCategory?
    let city: String?
    let eventDate: Date?
    let limit: Int

    init(
        text: String,
        category: VendorCategory?,
        city: String? = nil,
        eventDate: Date? = nil,
        limit: Int = 24
    ) {
        self.text = text
        self.category = category
        let trimmedCity = city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.city = trimmedCity.isEmpty ? nil : trimmedCity
        self.eventDate = eventDate
        self.limit = max(limit, 1)
    }

    var normalizedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }

    var searchTokens: [String] {
        normalizedText
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { String($0) }
            .map(Self.normalizeSearchToken)
            .filter { !$0.isEmpty && !Self.ignoredTokens.contains($0) }
    }

    var minimumTokenMatches: Int {
        switch searchTokens.count {
        case 0:
            0
        case 1...2:
            1
        default:
            2
        }
    }

    func tokenMatchScore(in haystack: String) -> Int {
        let normalizedHaystack = haystack.localizedLowercase

        return Set(searchTokens).reduce(into: 0) { score, token in
            if normalizedHaystack.contains(token) {
                score += 1
            }
        }
    }

    var fetchLimit: Int {
        let multiplier = normalizedText.isEmpty ? 3 : 5
        return min(max(limit * multiplier, 24), 120)
    }

    private static let ignoredTokens: Set<String> = [
        "a",
        "an",
        "and",
        "for",
        "in",
        "me",
        "near",
        "the",
        "to",
    ]

    private static let tokenOverrides: [String: String] = [
        "photographers": "photographer",
        "caterers": "caterer",
        "caters": "caterer",
        "decorators": "decorator",
        "decoraters": "decorator",
        "djs": "dj",
        "planners": "planner",
        "florists": "florist",
        "bakers": "baker",
        "entertainers": "entertainer",
        "bartenders": "bartender",
        "venues": "venue",
        "rentals": "rental",
        "musicians": "musician",
        "painters": "painter",
    ]

    private static func normalizeSearchToken(_ token: String) -> String {
        let normalized = token.localizedLowercase
        return tokenOverrides[normalized] ?? normalized
    }
}
