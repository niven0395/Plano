import Foundation

nonisolated enum LeadIntakeFieldType: String, CaseIterable, Identifiable, Codable, Sendable {
    case shortText = "short_text"
    case longText = "long_text"
    case singleChoice = "single_choice"
    case multiChoice = "multi_choice"
    case number

    var id: Self { self }

    var title: String {
        switch self {
        case .shortText:
            "Short answer"
        case .longText:
            "Long answer"
        case .singleChoice:
            "Single choice"
        case .multiChoice:
            "Multiple choice"
        case .number:
            "Number"
        }
    }
}

struct LeadIntakeQuestion: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var prompt: String
    var helperText: String
    var placeholder: String
    var responseType: LeadIntakeFieldType
    var options: [String]
    var isRequired: Bool
    var isEnabled: Bool

    init(
        id: String,
        prompt: String,
        helperText: String = "",
        placeholder: String = "",
        responseType: LeadIntakeFieldType = .shortText,
        options: [String] = [],
        isRequired: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.prompt = prompt
        self.helperText = helperText
        self.placeholder = placeholder
        self.responseType = responseType
        self.options = options
        self.isRequired = isRequired
        self.isEnabled = isEnabled
    }

    var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOptions: [String] {
        options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func normalized() -> LeadIntakeQuestion {
        LeadIntakeQuestion(
            id: id,
            prompt: trimmedPrompt,
            helperText: helperText.trimmingCharacters(in: .whitespacesAndNewlines),
            placeholder: placeholder.trimmingCharacters(in: .whitespacesAndNewlines),
            responseType: responseType,
            options: trimmedOptions,
            isRequired: isRequired,
            isEnabled: isEnabled
        )
    }

    func makeAnswer(values: [String] = []) -> LeadIntakeAnswer {
        LeadIntakeAnswer(
            questionID: id,
            prompt: trimmedPrompt,
            responseType: responseType,
            values: values
        )
    }
}

struct LeadIntakeAnswer: Identifiable, Hashable, Codable, Sendable {
    let questionID: String
    var prompt: String
    var responseType: LeadIntakeFieldType
    var values: [String]

    var id: String { questionID }

    init(
        questionID: String,
        prompt: String,
        responseType: LeadIntakeFieldType,
        values: [String] = []
    ) {
        self.questionID = questionID
        self.prompt = prompt
        self.responseType = responseType
        self.values = values
    }

    init(question: LeadIntakeQuestion, values: [String] = []) {
        self.init(
            questionID: question.id,
            prompt: question.trimmedPrompt,
            responseType: question.responseType,
            values: values
        )
    }

    var cleanedValues: [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var hasValue: Bool {
        !cleanedValues.isEmpty
    }

    var displayValue: String {
        let cleanedValues = cleanedValues
        guard !cleanedValues.isEmpty else { return "Not provided" }

        switch responseType {
        case .multiChoice:
            return cleanedValues.joined(separator: " · ")
        case .shortText, .longText, .singleChoice, .number:
            return cleanedValues.joined(separator: ", ")
        }
    }

    func normalized() -> LeadIntakeAnswer {
        let cleanedValues = cleanedValues
        let normalizedValues: [String]

        switch responseType {
        case .multiChoice:
            normalizedValues = cleanedValues
        case .shortText, .longText, .singleChoice, .number:
            normalizedValues = cleanedValues.first.map { [$0] } ?? []
        }

        return LeadIntakeAnswer(
            questionID: questionID,
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            responseType: responseType,
            values: normalizedValues
        )
    }
}

nonisolated enum LeadIntakeTemplateLibrary {
    static func resolvedQuestions(for category: VendorCategory, stored: [LeadIntakeQuestion]?) -> [LeadIntakeQuestion] {
        let normalized = (stored ?? []).map { $0.normalized() }
        return normalized.isEmpty ? defaultQuestions(for: category) : normalized
    }

    static func defaultQuestions(for category: VendorCategory) -> [LeadIntakeQuestion] {
        switch category {
        case .decorator, .florist:
            return [
                question(
                    category,
                    suffix: "visual-priority",
                    prompt: "What areas should stand out most?",
                    helperText: "Tell the vendor where the visual focus needs to land first.",
                    placeholder: "Backdrop, sweetheart table, entry moment...",
                    responseType: .shortText,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "palette",
                    prompt: "What colors or overall vibe are you aiming for?",
                    placeholder: "Soft neutrals, garden party, bold color...",
                    responseType: .longText,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "install-window",
                    prompt: "How much setup time is available on-site?",
                    helperText: "This helps the vendor judge install complexity.",
                    responseType: .singleChoice,
                    options: ["Under 1 hour", "1-2 hours", "2-4 hours", "Flexible"],
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "must-have-elements",
                    prompt: "List any must-have decor elements.",
                    placeholder: "Fresh florals, candles, welcome sign...",
                    responseType: .longText
                ),
            ]

        case .photographer:
            return [
                question(
                    category,
                    suffix: "coverage-hours",
                    prompt: "How many hours of coverage do you expect?",
                    responseType: .singleChoice,
                    options: ["1-2 hours", "3-4 hours", "5-6 hours", "8+ hours"],
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "deliverables",
                    prompt: "What deliverables matter most?",
                    responseType: .multiChoice,
                    options: ["Portraits", "Candid coverage", "Detail shots", "Video clips", "Print booth"],
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "shot-priority",
                    prompt: "Anything specific that cannot be missed?",
                    placeholder: "Family combinations, grand entrance, speeches...",
                    responseType: .longText,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "lighting-context",
                    prompt: "Is the event mainly indoors, outdoors, or mixed?",
                    responseType: .singleChoice,
                    options: ["Indoors", "Outdoors", "Mixed"],
                    isRequired: false
                ),
            ]

        case .dj, .entertainer, .photobooth:
            return [
                question(
                    category,
                    suffix: "service-window",
                    prompt: "How long do you need the performance or music service?",
                    responseType: .singleChoice,
                    options: ["1-2 hours", "3-4 hours", "5-6 hours", "All event"],
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "crowd-vibe",
                    prompt: "What energy or music style should the room have?",
                    placeholder: "Elegant dinner, dance floor, family-friendly...",
                    responseType: .longText,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "sound-restrictions",
                    prompt: "Are there venue sound rules or timing restrictions?",
                    placeholder: "Noise cap at 10pm, no outdoor speakers...",
                    responseType: .longText
                ),
                question(
                    category,
                    suffix: "must-play",
                    prompt: "Any must-play or do-not-play notes?",
                    placeholder: "Specific songs, genres, family-friendly notes...",
                    responseType: .longText
                ),
            ]

        case .caterer, .bartender, .baker, .appetizer, .experienceStation, .desserts:
            return [
                question(
                    category,
                    suffix: "service-style",
                    prompt: "What kind of food or beverage service do you want?",
                    responseType: .singleChoice,
                    options: ["Plated", "Buffet", "Stations", "Passed service", "Pickup / drop-off"],
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "dietary-needs",
                    prompt: "Are there dietary restrictions or menu preferences?",
                    placeholder: "Halal, nut-free, vegetarian, kids menu...",
                    responseType: .longText,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "service-duration",
                    prompt: "How long should service run?",
                    responseType: .singleChoice,
                    options: ["Under 2 hours", "2-4 hours", "4-6 hours", "All event"],
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "venue-kitchen",
                    prompt: "What venue setup is available?",
                    responseType: .singleChoice,
                    options: ["Full kitchen", "Prep area only", "No kitchen", "Not sure yet"]
                ),
            ]

        case .eventSpace, .studio:
            return [
                question(
                    category,
                    suffix: "layout-style",
                    prompt: "What kind of event layout do you need?",
                    responseType: .singleChoice,
                    options: ["Seated dinner", "Cocktail / mingling", "Ceremony + reception", "Kids / activity-based"],
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "timeline-window",
                    prompt: "What time window are you targeting?",
                    placeholder: "4pm setup, 6pm guest arrival, 11pm end...",
                    responseType: .longText,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "indoor-outdoor",
                    prompt: "Do you need indoor, outdoor, or both?",
                    responseType: .singleChoice,
                    options: ["Indoor", "Outdoor", "Both"],
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "venue-needs",
                    prompt: "Anything the venue absolutely needs to support?",
                    placeholder: "Parking, vendor access, bar, AV, late end time...",
                    responseType: .longText
                ),
            ]

        case .rental:
            return [
                question(
                    category,
                    suffix: "scope",
                    prompt: "What part of the event do you need help with?",
                    responseType: .multiChoice,
                    options: ["Full event support", "Day-of coordination", "Setup / breakdown", "Rentals only", "Staffing only"],
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "timeline-pressure",
                    prompt: "What feels most time-sensitive right now?",
                    placeholder: "Need a floor plan, vendor coordination, setup crew...",
                    responseType: .longText,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "delivery-access",
                    prompt: "Are there delivery or load-in constraints?",
                    placeholder: "Elevator access, loading dock timing, stairs...",
                    responseType: .longText
                ),
                question(
                    category,
                    suffix: "rental-window",
                    prompt: "How long do you need the service or rental coverage?",
                    responseType: .singleChoice,
                    options: ["Same day only", "Weekend", "Multiple days", "Not sure yet"]
                ),
            ]

        case .makeupArtist, .hairStylist:
            return [
                question(
                    category,
                    suffix: "service-count",
                    prompt: "How many people need this service?",
                    responseType: .number,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "readiness-time",
                    prompt: "When does everyone need to be ready?",
                    placeholder: "Ready by 3:30pm for photos...",
                    responseType: .shortText,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "style-reference",
                    prompt: "What look or inspiration are you going for?",
                    placeholder: "Natural glam, festival face paint, soft bridal...",
                    responseType: .longText,
                    isRequired: true
                ),
                question(
                    category,
                    suffix: "on-site-space",
                    prompt: "Any location or setup constraints?",
                    placeholder: "Hotel suite, no power nearby, outdoor tent...",
                    responseType: .longText
                ),
            ]

        }
    }

    private static func question(
        _ category: VendorCategory,
        suffix: String,
        prompt: String,
        helperText: String = "",
        placeholder: String = "",
        responseType: LeadIntakeFieldType,
        options: [String] = [],
        isRequired: Bool = false
    ) -> LeadIntakeQuestion {
        LeadIntakeQuestion(
            id: "\(category.rawValue)-\(suffix)",
            prompt: prompt,
            helperText: helperText,
            placeholder: placeholder,
            responseType: responseType,
            options: options,
            isRequired: isRequired,
            isEnabled: true
        )
    }
}
