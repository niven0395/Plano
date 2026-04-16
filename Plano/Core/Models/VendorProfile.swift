import Foundation

nonisolated struct VendorProfile: Identifiable, Hashable, Sendable {
    let id: UUID
    let businessName: String
    let businessEmail: String?
    let profileImagePath: String?
    let listingImagePath: String?
    let category: VendorCategory
    let customCategoryName: String?
    let bio: String
    let city: String
    let serviceArea: String
    let startingPrice: String
    let pricingModel: PricingModel
    let basePriceCents: Int?
    let hourlyRateCents: Int?
    let minimumHours: Int?
    let perPersonPriceCents: Int?
    let minimumGuests: Int?
    let pricingVisibility: PricingVisibility
    let weeklySchedule: WeeklySchedule
    let leadTimeDays: Int
    let advanceBookingDays: Int
    let timeslotConfig: TimeslotConfig
    let schedulingMode: SchedulingMode
    let bookingMode: BookingMode
    let paymentMode: PaymentMode
    let collectsGuestCount: Bool
    let cancellationDeadlineDays: Int?
    let phone: String?
    let website: String?
    let instagramHandle: String?
    let tiktokHandle: String?
    let tags: [String]
    let responseTime: String
    let ratingValue: Double
    let reviewCount: Int
    let badge: String
    let intro: String
    let styleSummary: String
    let availability: AvailabilitySignal
    let services: [String]
    let categoryDetails: CategoryDetails?
    let leadIntakeQuestions: [LeadIntakeQuestion]
    let policies: [VendorPolicy]
    let serviceItems: [VendorServiceItem]
    let packages: [VendorPackage]
    let addOns: [VendorAddOn]
    let pricingImagePaths: [String]
    let galleryHighlights: [String]
    let galleryImages: [VendorGalleryImage]
    let review: VendorReviewSnippet
    let reviewHighlights: [VendorReviewEntry]
    let availabilitySummary: VendorAvailabilitySummary
    let repeatBookingRateLabel: String
    let profileCompleteness: Int
    let searchMomentumScore: Int
    let onboardedAt: Date?

    init(
        id: UUID = UUID(),
        businessName: String,
        businessEmail: String? = nil,
        profileImagePath: String? = nil,
        listingImagePath: String? = nil,
        category: VendorCategory,
        customCategoryName: String? = nil,
        bio: String = "",
        city: String,
        serviceArea: String,
        startingPrice: String = "",
        pricingModel: PricingModel = .startingFrom,
        basePriceCents: Int? = nil,
        hourlyRateCents: Int? = nil,
        minimumHours: Int? = nil,
        perPersonPriceCents: Int? = nil,
        minimumGuests: Int? = nil,
        pricingVisibility: PricingVisibility = .public,
        weeklySchedule: WeeklySchedule? = nil,
        leadTimeDays: Int = 0,
        advanceBookingDays: Int = 180,
        timeslotConfig: TimeslotConfig = .disabled,
        schedulingMode: SchedulingMode = .calendar,
        availabilityMode: AvailabilityMode = .contactToDiscuss,
        bookingMode: BookingMode = .inquiryOnly,
        paymentMode: PaymentMode = .external,
        collectsGuestCount: Bool? = nil,
        cancellationDeadlineDays: Int? = nil,
        phone: String? = nil,
        website: String? = nil,
        instagramHandle: String? = nil,
        tiktokHandle: String? = nil,
        tags: [String] = [],
        responseTime: String,
        ratingValue: Double,
        reviewCount: Int,
        badge: String,
        intro: String,
        styleSummary: String,
        availability: AvailabilitySignal,
        services: [String],
        categoryDetails: CategoryDetails? = nil,
        leadIntakeQuestions: [LeadIntakeQuestion]? = nil,
        policies: [VendorPolicy] = [],
        serviceItems: [VendorServiceItem] = [],
        packages: [VendorPackage] = [],
        addOns: [VendorAddOn] = [],
        pricingImagePaths: [String] = [],
        galleryHighlights: [String],
        galleryImages: [VendorGalleryImage] = [],
        review: VendorReviewSnippet,
        reviewHighlights: [VendorReviewEntry],
        availabilitySummary: VendorAvailabilitySummary,
        repeatBookingRateLabel: String,
        profileCompleteness: Int,
        searchMomentumScore: Int,
        onboardedAt: Date? = .now
    ) {
        self.id = id
        self.businessName = businessName
        self.businessEmail = businessEmail
        self.profileImagePath = profileImagePath
        self.listingImagePath = listingImagePath
        self.category = category
        self.customCategoryName = customCategoryName
        self.bio = bio
        self.city = city
        self.serviceArea = serviceArea
        self.startingPrice = startingPrice
        self.pricingModel = pricingModel
        self.basePriceCents = basePriceCents
        self.hourlyRateCents = hourlyRateCents
        self.minimumHours = minimumHours
        self.perPersonPriceCents = perPersonPriceCents
        self.minimumGuests = minimumGuests
        self.pricingVisibility = pricingVisibility
        self.weeklySchedule = weeklySchedule ?? WeeklySchedule.legacyDefault(for: availabilityMode)
        self.leadTimeDays = min(max(leadTimeDays, 0), 90)
        self.advanceBookingDays = min(max(advanceBookingDays, 7), 365)
        self.timeslotConfig = timeslotConfig
        self.schedulingMode = schedulingMode
        self.bookingMode = bookingMode
        self.paymentMode = paymentMode
        self.collectsGuestCount = collectsGuestCount ?? category.defaultCollectsGuestCount
        self.cancellationDeadlineDays = cancellationDeadlineDays
        self.phone = phone
        self.website = website
        self.instagramHandle = instagramHandle
        self.tiktokHandle = tiktokHandle
        self.tags = tags
        self.responseTime = responseTime
        self.ratingValue = ratingValue
        self.reviewCount = reviewCount
        self.badge = badge
        self.intro = intro
        self.styleSummary = styleSummary
        self.availability = availability
        self.services = services
        self.categoryDetails = categoryDetails
        self.leadIntakeQuestions = leadIntakeQuestions ?? []
        self.policies = policies
        self.serviceItems = serviceItems.sorted { $0.displayOrder < $1.displayOrder }
        self.packages = packages.sorted { $0.displayOrder < $1.displayOrder }
        self.addOns = addOns.sorted { $0.displayOrder < $1.displayOrder }
        self.pricingImagePaths = pricingImagePaths
        self.galleryHighlights = galleryHighlights
        self.galleryImages = galleryImages
        self.review = review
        self.reviewHighlights = reviewHighlights
        self.availabilitySummary = availabilitySummary
        self.repeatBookingRateLabel = repeatBookingRateLabel
        self.profileCompleteness = profileCompleteness
        self.searchMomentumScore = searchMomentumScore
        self.onboardedAt = onboardedAt
    }

    var hasTimeslots: Bool {
        schedulingMode == .timeslots
    }

    var usesEventTimeRange: Bool {
        schedulingMode == .eventTimeRange
    }

    var isInquiryOnly: Bool {
        bookingMode == .inquiryOnly
    }

    var eventTimeRangeLabel: String? {
        guard schedulingMode == .eventTimeRange else { return nil }
        return "\(timeslotConfig.dailyStartTimeLabel) – \(timeslotConfig.dailyEndTimeLabel)"
    }

    var availabilityMode: AvailabilityMode {
        weeklySchedule.derivedAvailabilityMode(for: bookingMode)
    }

    var ratingText: String {
        ratingValue.formatted(.number.precision(.fractionLength(1)))
    }

    var displayCategoryTitle: String {
        if let customCategoryName,
           !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return category.singularTitle
    }

    var responseMinutes: Int {
        Int(responseTime.filter(\.isNumber)) ?? 999
    }

    var priceValue: Double {
        if let normalizedBasePriceCents {
            return Double(normalizedBasePriceCents) / 100
        }

        if let legacyStartingPriceCents {
            return Double(legacyStartingPriceCents) / 100
        }

        return 0
    }

    var searchMomentumLabel: String {
        if searchMomentumScore >= 90 {
            "Strong conversion signal"
        } else if searchMomentumScore >= 75 {
            "High shortlist momentum"
        } else {
            "Steady discovery signal"
        }
    }

    var visibleStartingPriceLabel: String? {
        switch pricingVisibility {
        case .public:
            if let pricingLabel {
                return pricingLabel
            }

            return startingPrice.isEmpty ? nil : startingPrice
        case .onRequest:
            return "Pricing on request"
        case .hidden:
            return nil
        }
    }

    var visiblePricingDetailLabel: String? {
        switch pricingVisibility {
        case .public:
            if let pricingLabel {
                return pricingLabel
            }

            return startingPrice.isEmpty ? nil : startingPrice
        case .onRequest:
            return "Pricing on request"
        case .hidden:
            return nil
        }
    }

    var planningPriceLabel: String {
        visibleStartingPriceLabel ?? "Pricing on request"
    }

    var sharedPriceValue: Double? {
        guard pricingVisibility == .public else { return nil }
        let resolvedValue = priceValue
        return resolvedValue > 0 ? resolvedValue : nil
    }

    var hostBookingLabel: String {
        bookingMode.hostSummaryTitle
    }

    var enabledLeadIntakeQuestions: [LeadIntakeQuestion] {
        leadIntakeQuestions.filter(\.isEnabled)
    }

    var hostPaymentLabel: String {
        paymentMode.hostSummaryTitle
    }

    var hostRouteSummary: String {
        "\(hostBookingLabel) · \(hostPaymentLabel)"
    }

    var primaryCTA: String {
        switch bookingMode {
        case .acceptOnline:
            "Book now"
        case .requestOnly:
            "Request booking"
        case .inquiryOnly:
            "Send inquiry"
        }
    }

    var socialLinks: [VendorSocialLink] {
        [
            instagramHandle.map { VendorSocialLink(kind: .instagram, value: $0) },
            website.map { VendorSocialLink(kind: .website, value: $0) },
            phone.map { VendorSocialLink(kind: .phone, value: $0) },
            tiktokHandle.map { VendorSocialLink(kind: .tiktok, value: $0) },
        ]
        .compactMap { $0 }
    }

    var summary: VendorSummary {
        VendorSummary(
            id: id,
            businessName: businessName,
            category: category,
            city: city,
            startingPrice: visibleStartingPriceLabel ?? "Request a quote",
            responseTime: responseTime,
            ratingText: ratingText,
            highlight: styleSummary,
            badge: badge
        )
    }

    private var normalizedBasePriceCents: Int? {
        if let basePriceCents, basePriceCents > 0 {
            return basePriceCents
        }

        switch pricingModel {
        case .startingFrom, .perEvent:
            return nil
        case .perHour:
            guard let hourlyRateCents, hourlyRateCents > 0 else { return nil }
            return hourlyRateCents * max(minimumHours ?? 1, 1)
        case .perPerson:
            guard let perPersonPriceCents, perPersonPriceCents > 0 else { return nil }
            return perPersonPriceCents * max(minimumGuests ?? 1, 1)
        case .custom:
            if let lowestItemPrice = serviceItems.map(\.priceCents).filter({ $0 > 0 }).min() {
                return lowestItemPrice
            }
            return nil
        }
    }

    private var legacyStartingPriceCents: Int? {
        let trimmed = startingPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased().replacingOccurrences(of: ",", with: "")
        let multiplier: Double = normalized.contains("k") ? 1_000 : 1
        let numericCharacters = normalized.filter { $0.isNumber || $0 == "." }

        guard let value = Double(numericCharacters), value > 0 else { return nil }
        return Int((value * multiplier * 100).rounded())
    }

    private var pricingLabel: String? {
        switch pricingModel {
        case .startingFrom:
            guard let anchorPrice = normalizedBasePriceCents else { return nil }
            return "From \(PricingAmountFormatter.currencyLabel(forCents: anchorPrice))"
        case .perEvent:
            guard let anchorPrice = normalizedBasePriceCents else { return nil }
            return "\(PricingAmountFormatter.currencyLabel(forCents: anchorPrice)) per event"
        case .perHour:
            guard let hourlyRateCents, hourlyRateCents > 0 else { return nil }
            let rateLabel = "\(PricingAmountFormatter.currencyLabel(forCents: hourlyRateCents))/hr"
            let minimumHours = max(minimumHours ?? 1, 1)
            return rateLabel + (minimumHours > 1 ? " (\(minimumHours) hr min)" : "")
        case .perPerson:
            guard let perPersonPriceCents, perPersonPriceCents > 0 else { return nil }
            let rateLabel = "\(PricingAmountFormatter.currencyLabel(forCents: perPersonPriceCents))/person"
            let minimumGuests = max(minimumGuests ?? 1, 1)
            return rateLabel + (minimumGuests > 1 ? " (\(minimumGuests) guest min)" : "")
        case .custom:
            let positiveItemPrices = serviceItems.map(\.priceCents).filter { $0 > 0 }

            if let lowestPrice = positiveItemPrices.min() {
                let lowestLabel = PricingAmountFormatter.currencyLabel(forCents: lowestPrice)

                if let highestPrice = positiveItemPrices.max(), highestPrice != lowestPrice {
                    return "\(lowestLabel) - \(PricingAmountFormatter.currencyLabel(forCents: highestPrice))"
                }

                return lowestLabel
            }

            if let anchorPrice = normalizedBasePriceCents {
                return "From \(PricingAmountFormatter.currencyLabel(forCents: anchorPrice))"
            }

            return nil
        }
    }
}
