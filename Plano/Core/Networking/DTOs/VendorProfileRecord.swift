import Foundation

nonisolated struct VendorProfileRecord: Codable, Hashable {
    let userID: UUID
    let businessName: String
    let businessEmail: String?
    let profileImagePath: String?
    let category: String?
    let customCategoryName: String?
    let bio: String?
    let styleSummary: String?
    let city: String?
    let serviceArea: String?
    let startingPrice: String?
    let priceTier: String?
    let pricingModel: String?
    let basePriceCents: Int?
    let hourlyRateCents: Int?
    let minimumHours: Int?
    let perPersonPriceCents: Int?
    let minimumGuests: Int?
    let priceTierOverride: String?
    let pricingVisibility: String?
    let availabilityMode: String?
    let availableDays: [Int]?
    let schedulePreset: String?
    let leadTimeDays: Int?
    let advanceBookingDays: Int?
    let bookingMode: String?
    let paymentMode: String?
    let cancellationDeadlineDays: Int?
    let phone: String?
    let website: String?
    let instagramHandle: String?
    let tiktokHandle: String?
    let services: [String]?
    let categoryDetails: CategoryDetails?
    let leadIntakeQuestions: [LeadIntakeQuestion]?
    let policies: [VendorPolicy]?
    let timeslotsEnabled: Bool?
    let timeslotDurationMinutes: Int?
    let timeslotStartHour: Int?
    let timeslotStartMinute: Int?
    let timeslotEndHour: Int?
    let timeslotEndMinute: Int?
    let timeslotBufferMinutes: Int?
    let timeslotRollingWindowDays: Int?
    let timeslotTimezone: String?
    let profileCompleteness: Int?
    let tags: [String]?
    let onboardedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case businessName = "business_name"
        case businessEmail = "business_email"
        case profileImagePath = "profile_image_path"
        case category
        case customCategoryName = "custom_category_name"
        case bio
        case styleSummary = "style_summary"
        case city
        case serviceArea = "service_area"
        case startingPrice = "starting_price"
        case priceTier = "price_tier"
        case pricingModel = "pricing_model"
        case basePriceCents = "base_price_cents"
        case hourlyRateCents = "hourly_rate_cents"
        case minimumHours = "minimum_hours"
        case perPersonPriceCents = "per_person_price_cents"
        case minimumGuests = "minimum_guests"
        case priceTierOverride = "price_tier_override"
        case pricingVisibility = "pricing_visibility"
        case availabilityMode = "availability_mode"
        case availableDays = "available_days"
        case schedulePreset = "schedule_preset"
        case leadTimeDays = "lead_time_days"
        case advanceBookingDays = "advance_booking_days"
        case bookingMode = "booking_mode"
        case paymentMode = "payment_mode"
        case cancellationDeadlineDays = "cancellation_deadline_days"
        case phone
        case website
        case instagramHandle = "instagram_handle"
        case tiktokHandle = "tiktok_handle"
        case services
        case categoryDetails = "category_details"
        case leadIntakeQuestions = "lead_intake_questions"
        case policies
        case timeslotsEnabled = "timeslots_enabled"
        case timeslotDurationMinutes = "timeslot_duration_minutes"
        case timeslotStartHour = "timeslot_start_hour"
        case timeslotStartMinute = "timeslot_start_minute"
        case timeslotEndHour = "timeslot_end_hour"
        case timeslotEndMinute = "timeslot_end_minute"
        case timeslotBufferMinutes = "timeslot_buffer_minutes"
        case timeslotRollingWindowDays = "timeslot_rolling_window_days"
        case timeslotTimezone = "timeslot_timezone"
        case profileCompleteness = "profile_completeness"
        case tags
        case onboardedAt = "onboarded_at"
    }

    init(
        userID: UUID,
        businessName: String,
        businessEmail: String? = nil,
        profileImagePath: String? = nil,
        category: String? = nil,
        customCategoryName: String? = nil,
        bio: String? = nil,
        styleSummary: String? = nil,
        city: String? = nil,
        serviceArea: String? = nil,
        startingPrice: String? = nil,
        priceTier: String? = nil,
        pricingModel: String? = nil,
        basePriceCents: Int? = nil,
        hourlyRateCents: Int? = nil,
        minimumHours: Int? = nil,
        perPersonPriceCents: Int? = nil,
        minimumGuests: Int? = nil,
        priceTierOverride: String? = nil,
        pricingVisibility: String? = nil,
        availabilityMode: String? = nil,
        availableDays: [Int]? = nil,
        schedulePreset: String? = nil,
        leadTimeDays: Int? = nil,
        advanceBookingDays: Int? = nil,
        bookingMode: String? = nil,
        paymentMode: String? = nil,
        cancellationDeadlineDays: Int? = nil,
        phone: String? = nil,
        website: String? = nil,
        instagramHandle: String? = nil,
        tiktokHandle: String? = nil,
        services: [String]? = nil,
        categoryDetails: CategoryDetails? = nil,
        leadIntakeQuestions: [LeadIntakeQuestion]? = nil,
        policies: [VendorPolicy]? = nil,
        timeslotsEnabled: Bool? = nil,
        timeslotDurationMinutes: Int? = nil,
        timeslotStartHour: Int? = nil,
        timeslotStartMinute: Int? = nil,
        timeslotEndHour: Int? = nil,
        timeslotEndMinute: Int? = nil,
        timeslotBufferMinutes: Int? = nil,
        timeslotRollingWindowDays: Int? = nil,
        timeslotTimezone: String? = nil,
        profileCompleteness: Int? = nil,
        tags: [String]? = nil,
        onboardedAt: Date? = nil
    ) {
        self.userID = userID
        self.businessName = businessName
        self.businessEmail = businessEmail
        self.profileImagePath = profileImagePath
        self.category = category
        self.customCategoryName = customCategoryName
        self.bio = bio
        self.styleSummary = styleSummary
        self.city = city
        self.serviceArea = serviceArea
        self.startingPrice = startingPrice
        self.priceTier = priceTier
        self.pricingModel = pricingModel
        self.basePriceCents = basePriceCents
        self.hourlyRateCents = hourlyRateCents
        self.minimumHours = minimumHours
        self.perPersonPriceCents = perPersonPriceCents
        self.minimumGuests = minimumGuests
        self.priceTierOverride = priceTierOverride
        self.pricingVisibility = pricingVisibility
        self.availabilityMode = availabilityMode
        self.availableDays = availableDays
        self.schedulePreset = schedulePreset
        self.leadTimeDays = leadTimeDays
        self.advanceBookingDays = advanceBookingDays
        self.bookingMode = bookingMode
        self.paymentMode = paymentMode
        self.cancellationDeadlineDays = cancellationDeadlineDays
        self.phone = phone
        self.website = website
        self.instagramHandle = instagramHandle
        self.tiktokHandle = tiktokHandle
        self.services = services
        self.categoryDetails = categoryDetails
        self.leadIntakeQuestions = leadIntakeQuestions
        self.policies = policies
        self.timeslotsEnabled = timeslotsEnabled
        self.timeslotDurationMinutes = timeslotDurationMinutes
        self.timeslotStartHour = timeslotStartHour
        self.timeslotStartMinute = timeslotStartMinute
        self.timeslotEndHour = timeslotEndHour
        self.timeslotEndMinute = timeslotEndMinute
        self.timeslotBufferMinutes = timeslotBufferMinutes
        self.timeslotRollingWindowDays = timeslotRollingWindowDays
        self.timeslotTimezone = timeslotTimezone
        self.profileCompleteness = profileCompleteness
        self.tags = tags
        self.onboardedAt = onboardedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(UUID.self, forKey: .userID)
        businessName = try container.decode(String.self, forKey: .businessName)
        businessEmail = try container.decodeIfPresent(String.self, forKey: .businessEmail)
        profileImagePath = try container.decodeIfPresent(String.self, forKey: .profileImagePath)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        customCategoryName = try container.decodeIfPresent(String.self, forKey: .customCategoryName)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        styleSummary = try container.decodeIfPresent(String.self, forKey: .styleSummary)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        serviceArea = try container.decodeIfPresent(String.self, forKey: .serviceArea)
        startingPrice = try container.decodeIfPresent(String.self, forKey: .startingPrice)
        priceTier = try container.decodeIfPresent(String.self, forKey: .priceTier)
        pricingModel = try container.decodeIfPresent(String.self, forKey: .pricingModel)
        basePriceCents = try container.decodeIfPresent(Int.self, forKey: .basePriceCents)
        hourlyRateCents = try container.decodeIfPresent(Int.self, forKey: .hourlyRateCents)
        minimumHours = try container.decodeIfPresent(Int.self, forKey: .minimumHours)
        perPersonPriceCents = try container.decodeIfPresent(Int.self, forKey: .perPersonPriceCents)
        minimumGuests = try container.decodeIfPresent(Int.self, forKey: .minimumGuests)
        priceTierOverride = try container.decodeIfPresent(String.self, forKey: .priceTierOverride)
        pricingVisibility = try container.decodeIfPresent(String.self, forKey: .pricingVisibility)
        availabilityMode = try container.decodeIfPresent(String.self, forKey: .availabilityMode)
        availableDays = try container.decodeIfPresent([Int].self, forKey: .availableDays)
        schedulePreset = try container.decodeIfPresent(String.self, forKey: .schedulePreset)
        leadTimeDays = try container.decodeIfPresent(Int.self, forKey: .leadTimeDays)
        advanceBookingDays = try container.decodeIfPresent(Int.self, forKey: .advanceBookingDays)
        bookingMode = try container.decodeIfPresent(String.self, forKey: .bookingMode)
        paymentMode = try container.decodeIfPresent(String.self, forKey: .paymentMode)
        cancellationDeadlineDays = try container.decodeIfPresent(Int.self, forKey: .cancellationDeadlineDays)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        instagramHandle = try container.decodeIfPresent(String.self, forKey: .instagramHandle)
        tiktokHandle = try container.decodeIfPresent(String.self, forKey: .tiktokHandle)
        services = try container.decodeIfPresent([String].self, forKey: .services)
        // category_details may be an empty object {} in the database, which lacks the
        // required "type" discriminator and cannot be decoded as CategoryDetails. Treat
        // any decoding failure as nil.
        categoryDetails = try? container.decodeIfPresent(CategoryDetails.self, forKey: .categoryDetails)
        leadIntakeQuestions = try container.decodeIfPresent([LeadIntakeQuestion].self, forKey: .leadIntakeQuestions)
        policies = try container.decodeIfPresent([VendorPolicy].self, forKey: .policies)
        timeslotsEnabled = try container.decodeIfPresent(Bool.self, forKey: .timeslotsEnabled)
        timeslotDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .timeslotDurationMinutes)
        timeslotStartHour = try container.decodeIfPresent(Int.self, forKey: .timeslotStartHour)
        timeslotStartMinute = try container.decodeIfPresent(Int.self, forKey: .timeslotStartMinute)
        timeslotEndHour = try container.decodeIfPresent(Int.self, forKey: .timeslotEndHour)
        timeslotEndMinute = try container.decodeIfPresent(Int.self, forKey: .timeslotEndMinute)
        timeslotBufferMinutes = try container.decodeIfPresent(Int.self, forKey: .timeslotBufferMinutes)
        timeslotRollingWindowDays = try container.decodeIfPresent(Int.self, forKey: .timeslotRollingWindowDays)
        timeslotTimezone = try container.decodeIfPresent(String.self, forKey: .timeslotTimezone)
        profileCompleteness = try container.decodeIfPresent(Int.self, forKey: .profileCompleteness)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        onboardedAt = try container.decodeIfPresent(Date.self, forKey: .onboardedAt)
    }

    init(profile: VendorProfile) {
        userID = profile.id
        businessName = profile.businessName
        businessEmail = profile.businessEmail
        profileImagePath = profile.profileImagePath
        category = profile.category.rawValue
        customCategoryName = profile.customCategoryName
        bio = profile.bio
        styleSummary = profile.styleSummary
        city = profile.city
        serviceArea = profile.serviceArea
        startingPrice = profile.startingPrice
        priceTier = profile.priceTier?.rawValue
        pricingModel = profile.pricingModel.rawValue
        basePriceCents = profile.basePriceCents
        hourlyRateCents = profile.hourlyRateCents
        minimumHours = profile.minimumHours
        perPersonPriceCents = profile.perPersonPriceCents
        minimumGuests = profile.minimumGuests
        priceTierOverride = profile.priceTierOverride?.rawValue
        pricingVisibility = profile.pricingVisibility.rawValue
        availabilityMode = profile.availabilityMode.rawValue
        availableDays = profile.weeklySchedule.availableDays.sorted().map(\.rawValue)
        schedulePreset = profile.weeklySchedule.preset.rawValue
        leadTimeDays = profile.leadTimeDays
        advanceBookingDays = profile.advanceBookingDays
        bookingMode = profile.bookingMode.rawValue
        paymentMode = profile.paymentMode.rawValue
        cancellationDeadlineDays = profile.cancellationDeadlineDays
        phone = profile.phone
        website = profile.website
        instagramHandle = profile.instagramHandle
        tiktokHandle = profile.tiktokHandle
        services = profile.services
        categoryDetails = profile.categoryDetails
        leadIntakeQuestions = profile.leadIntakeQuestions
        policies = profile.policies
        timeslotsEnabled = profile.timeslotConfig.isEnabled
        timeslotDurationMinutes = profile.timeslotConfig.durationMinutes
        timeslotStartHour = profile.timeslotConfig.startHour
        timeslotStartMinute = profile.timeslotConfig.startMinute
        timeslotEndHour = profile.timeslotConfig.endHour
        timeslotEndMinute = profile.timeslotConfig.endMinute
        timeslotBufferMinutes = profile.timeslotConfig.bufferMinutes
        timeslotRollingWindowDays = profile.timeslotConfig.rollingWindowDays
        timeslotTimezone = profile.timeslotConfig.timezone
        profileCompleteness = profile.profileCompleteness
        tags = profile.tags
        onboardedAt = profile.onboardedAt
    }

    func makeVendorProfile(
        fallbackCategory: VendorCategory = .entertainer,
        responseTime: String = "Responds in 1h",
        ratingValue: Double = 4.8,
        reviewCount: Int = 12,
        badge: String = "Fresh profile",
        intro: String? = nil,
        availability: AvailabilitySignal = .bookingFast,
        services: [String] = [],
        serviceItems: [VendorServiceItem] = [],
        packages: [VendorPackage] = [],
        galleryImages: [VendorGalleryImage] = [],
        review: VendorReviewSnippet = VendorReviewSnippet(
            author: "Recent host",
            eventTypeLabel: "Private event",
            quote: "Clear communication and a calm booking process."
        ),
        reviewHighlights: [VendorReviewEntry] = [],
        availabilitySummary: VendorAvailabilitySummary = VendorAvailabilitySummary(
            nextOpeningLabel: "Availability on request",
            leadTimeLabel: "Lead time varies",
            eventDateSupportLabel: "Availability is confirmed after the request is reviewed.",
            supportsSelectedEventDate: true,
            windows: []
        ),
        repeatBookingRateLabel: String = "New listing",
        searchMomentumScore: Int = 72
    ) -> VendorProfile {
        let category = self.category.flatMap(VendorCategory.init(rawValue:)) ?? fallbackCategory
        let resolvedServices = services.isEmpty ? (self.services ?? []) : services
        let resolvedBookingMode = bookingMode.flatMap(BookingMode.init(rawValue:)) ?? .inquiryOnly
        let resolvedLegacyAvailabilityMode = availabilityMode.flatMap(AvailabilityMode.init(rawValue:))
        let resolvedWeeklySchedule = WeeklySchedule.resolve(
            rawPreset: schedulePreset,
            availableDayValues: availableDays,
            fallbackAvailabilityMode: resolvedLegacyAvailabilityMode
        )
        let styleSummary = (styleSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? styleSummary!.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        let bio = (bio?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? bio!.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        let galleryHighlights = galleryImages
            .sorted { $0.displayOrder < $1.displayOrder }
            .compactMap { image in
                let trimmed = image.caption.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

        let resolvedTimeslotConfig = TimeslotConfig(
            isEnabled: timeslotsEnabled ?? false,
            durationMinutes: timeslotDurationMinutes ?? 60,
            startHour: timeslotStartHour ?? 9,
            startMinute: timeslotStartMinute ?? 0,
            endHour: timeslotEndHour ?? 17,
            endMinute: timeslotEndMinute ?? 0,
            bufferMinutes: timeslotBufferMinutes ?? 0,
            rollingWindowDays: timeslotRollingWindowDays ?? 14,
            timezone: timeslotTimezone ?? TimeZone.current.identifier
        )

        return VendorProfile(
            id: userID,
            businessName: businessName,
            businessEmail: businessEmail,
            profileImagePath: profileImagePath,
            category: category,
            customCategoryName: customCategoryName,
            bio: bio,
            city: city ?? "Toronto",
            serviceArea: serviceArea ?? "Greater Toronto Area",
            startingPrice: startingPrice ?? "",
            priceTier: priceTier.flatMap(PriceTier.init(rawValue:)),
            pricingModel: pricingModel.flatMap(PricingModel.init(rawValue:)) ?? .startingFrom,
            basePriceCents: basePriceCents,
            hourlyRateCents: hourlyRateCents,
            minimumHours: minimumHours,
            perPersonPriceCents: perPersonPriceCents,
            minimumGuests: minimumGuests,
            priceTierOverride: priceTierOverride.flatMap(PriceTier.init(rawValue:)),
            pricingVisibility: pricingVisibility.flatMap(PricingVisibility.init(rawValue:)) ?? .public,
            weeklySchedule: resolvedWeeklySchedule,
            leadTimeDays: Self.clampedLeadTimeDays(leadTimeDays),
            advanceBookingDays: Self.clampedAdvanceBookingDays(advanceBookingDays),
            timeslotConfig: resolvedTimeslotConfig,
            availabilityMode: resolvedWeeklySchedule.derivedAvailabilityMode(for: resolvedBookingMode),
            bookingMode: resolvedBookingMode,
            paymentMode: paymentMode.flatMap(PaymentMode.init(rawValue:)) ?? .external,
            cancellationDeadlineDays: cancellationDeadlineDays,
            phone: phone,
            website: website,
            instagramHandle: instagramHandle,
            tiktokHandle: tiktokHandle,
            tags: tags ?? [],
            responseTime: responseTime,
            ratingValue: ratingValue,
            reviewCount: reviewCount,
            badge: badge,
            intro: intro ?? bio,
            styleSummary: styleSummary,
            availability: availability,
            services: resolvedServices,
            categoryDetails: categoryDetails,
            leadIntakeQuestions: LeadIntakeTemplateLibrary.resolvedQuestions(for: category, stored: leadIntakeQuestions),
            policies: policies ?? [],
            serviceItems: serviceItems,
            packages: packages,
            galleryHighlights: galleryHighlights,
            galleryImages: galleryImages,
            review: review,
            reviewHighlights: reviewHighlights,
            availabilitySummary: availabilitySummary,
            repeatBookingRateLabel: repeatBookingRateLabel,
            profileCompleteness: profileCompleteness ?? 10,
            searchMomentumScore: searchMomentumScore,
            onboardedAt: onboardedAt
        )
    }

    private static func clampedLeadTimeDays(_ value: Int?) -> Int {
        min(max(value ?? 0, 0), 90)
    }

    private static func clampedAdvanceBookingDays(_ value: Int?) -> Int {
        min(max(value ?? 180, 7), 365)
    }
}
