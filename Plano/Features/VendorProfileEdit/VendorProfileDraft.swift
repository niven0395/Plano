import Foundation

struct VendorProfileDraft: Hashable {
    var businessName = ""
    var businessEmail = ""
    var category: VendorCategory = .decorator
    var customCategoryName = ""
    var bio = ""
    var styleSummary = ""
    var city = ""
    var serviceArea = ""
    var startingPrice = ""
    var pricingModel: PricingModel = .startingFrom
    var basePriceCents: Int?
    var hourlyRateCents: Int?
    var minimumHours: Int?
    var perPersonPriceCents: Int?
    var minimumGuests: Int?
    var pricingVisibility: PricingVisibility = .public
    var schedulePreset: SchedulePreset = .everyDay
    var availableDays: Set<Weekday> = Set(Weekday.allCases)
    var leadTimeDays = 0
    var advanceBookingDays = 180
    var bookingMode: BookingMode = .inquiryOnly
    var paymentMode: PaymentMode = .external
    var cancellationDeadlineDays: Int?
    var schedulingMode: SchedulingMode = .calendar
    var timeslotDurationMinutes = 60
    var timeslotStartHour = 9
    var timeslotStartMinute = 0
    var timeslotEndHour = 17
    var timeslotEndMinute = 0
    var timeslotBufferMinutes = 0
    var timeslotRollingWindowDays = 14
    var timeslotTimezone = TimeZone.current.identifier
    var phone = ""
    var website = ""
    var instagramHandle = ""
    var tiktokHandle = ""
    var tags: [String] = []
    var collectsGuestCount = true
    var categoryDetails: CategoryDetails?
    var services: [String] = []
    var leadIntakeQuestions: [LeadIntakeQuestion] = []
    var policies: [VendorPolicy] = []
    var serviceItems: [VendorServiceItem] = []
    var packages: [VendorPackage] = []
    var addOns: [VendorAddOn] = []
    var pricingImagePaths: [String] = []
    var profileImagePath: String?
    var listingImagePath: String?
    var galleryImages: [VendorGalleryImage] = []

    var enabledLeadIntakeQuestions: [LeadIntakeQuestion] {
        leadIntakeQuestions
            .map { $0.normalized() }
            .filter(\.isEnabled)
    }

    var computedBasePriceCents: Int? {
        switch pricingModel {
        case .startingFrom, .perEvent:
            return normalizedPositive(basePriceCents) ?? Self.legacyPriceCents(from: startingPrice)
        case .perHour:
            guard let hourlyRateCents = normalizedPositive(hourlyRateCents) else { return nil }
            return hourlyRateCents * max(minimumHours ?? 1, 1)
        case .perPerson:
            guard let perPersonPriceCents = normalizedPositive(perPersonPriceCents) else { return nil }
            return perPersonPriceCents * max(minimumGuests ?? 1, 1)
        case .custom:
            return preparedServiceItems.map(\.priceCents).filter { $0 > 0 }.min() ?? Self.legacyPriceCents(from: startingPrice)
        }
    }

    var displayPriceLabel: String? {
        switch pricingModel {
        case .startingFrom:
            guard let basePriceCents = computedBasePriceCents else { return nil }
            return "From \(Self.currencyLabel(forCents: basePriceCents))"
        case .perEvent:
            guard let basePriceCents = normalizedPositive(basePriceCents) else { return nil }
            return "\(Self.currencyLabel(forCents: basePriceCents)) per event"
        case .perHour:
            guard let hourlyRateCents = normalizedPositive(hourlyRateCents) else { return nil }
            let minimumHours = max(self.minimumHours ?? 1, 1)
            let minimumSuffix = minimumHours > 1 ? " (\(minimumHours) hr min)" : ""
            return "\(Self.currencyLabel(forCents: hourlyRateCents))/hr\(minimumSuffix)"
        case .perPerson:
            guard let perPersonPriceCents = normalizedPositive(perPersonPriceCents) else { return nil }
            let minimumGuests = max(self.minimumGuests ?? 1, 1)
            let minimumSuffix = minimumGuests > 1 ? " (\(minimumGuests) guest min)" : ""
            return "\(Self.currencyLabel(forCents: perPersonPriceCents))/person\(minimumSuffix)"
        case .custom:
            let serviceItems = preparedServiceItems
            let prices = serviceItems.map(\.priceCents).filter { $0 > 0 }

            guard let lowest = prices.min() else {
                return nil
            }

            let lowestLabel = Self.currencyLabel(forCents: lowest)
            if let highest = prices.max(), highest != lowest {
                return "\(lowestLabel) - \(Self.currencyLabel(forCents: highest))"
            }

            return lowestLabel
        }
    }

    var preparedServiceItems: [VendorServiceItem] {
        serviceItems.enumerated().compactMap { index, item in
            let title = item.title.trimmed
            guard !title.isEmpty else { return nil }

            return VendorServiceItem(
                id: item.id,
                title: title,
                priceCents: max(item.priceCents, 0),
                description: item.description.trimmed,
                displayOrder: index
            )
        }
    }

    var preparedPackages: [VendorPackage] {
        packages.enumerated().compactMap { index, pkg in
            let title = pkg.title.trimmed
            guard !title.isEmpty else { return nil }

            return VendorPackage(
                id: pkg.id,
                title: title,
                priceCents: max(pkg.priceCents, 0),
                description: pkg.description.trimmed,
                includedItems: pkg.includedItems.map(\.trimmed).filter { !$0.isEmpty },
                isHighlighted: pkg.isHighlighted,
                pricingUnit: pkg.pricingUnit,
                displayOrder: index
            )
        }
    }

    var preparedAddOns: [VendorAddOn] {
        addOns.enumerated().compactMap { index, addOn in
            let title = addOn.title.trimmed
            guard !title.isEmpty else { return nil }

            return VendorAddOn(
                id: addOn.id,
                title: title,
                priceCents: max(addOn.priceCents, 0),
                description: addOn.description.trimmed,
                displayOrder: index
            )
        }
    }

    var weeklySchedule: WeeklySchedule {
        WeeklySchedule(
            preset: schedulePreset,
            availableDays: availableDays
        )
    }

    var timeslotConfig: TimeslotConfig {
        TimeslotConfig(
            isEnabled: schedulingMode == .timeslots,
            durationMinutes: timeslotDurationMinutes,
            startHour: timeslotStartHour,
            startMinute: timeslotStartMinute,
            endHour: timeslotEndHour,
            endMinute: timeslotEndMinute,
            bufferMinutes: timeslotBufferMinutes,
            rollingWindowDays: timeslotRollingWindowDays,
            timezone: timeslotTimezone
        )
    }

    var availabilityMode: AvailabilityMode {
        weeklySchedule.derivedAvailabilityMode(for: bookingMode)
    }

    var profileCompleteness: Int {
        var score = 0

        if !businessName.trimmed.isEmpty {
            score += 15
        }

        if !city.trimmed.isEmpty {
            score += 10
        }

        if !bio.trimmed.isEmpty {
            score += 15
        }

        if !tags.isEmpty {
            score += 5
        }

        if computedBasePriceCents != nil {
            score += 10
        }

        if !availableDays.isEmpty {
            score += 10
        }

        if !phone.trimmed.isEmpty || !website.trimmed.isEmpty {
            score += 10
        }

        if !instagramHandle.trimmed.isEmpty || !tiktokHandle.trimmed.isEmpty {
            score += 5
        }

        if !galleryImages.isEmpty {
            score += 10
        }

        if !styleSummary.trimmed.isEmpty {
            score += 5
        }

        if !serviceArea.trimmed.isEmpty {
            score += 5
        }

        if let categoryDetails, !categoryDetails.isEmpty {
            score += 10
        }

        return min(score, 100)
    }

    mutating func apply(
        record: VendorProfileRecord,
        galleryImages: [VendorGalleryImage],
        serviceItems: [VendorServiceItem],
        packages: [VendorPackage] = [],
        addOns: [VendorAddOn] = []
    ) {
        profileImagePath = record.profileImagePath
        listingImagePath = record.listingImagePath
        businessName = record.businessName
        businessEmail = record.businessEmail ?? ""
        category = record.category.flatMap(VendorCategory.fromDatabaseValue) ?? .decorator
        customCategoryName = record.customCategoryName ?? ""
        bio = record.bio ?? ""
        styleSummary = record.styleSummary ?? ""
        city = record.city ?? ""
        serviceArea = record.serviceArea ?? ""
        startingPrice = record.startingPrice ?? ""
        pricingModel = record.pricingModel.flatMap(PricingModel.init(rawValue:)) ?? .startingFrom
        basePriceCents = normalizedPositive(record.basePriceCents) ?? Self.legacyPriceCents(from: record.startingPrice)
        hourlyRateCents = normalizedPositive(record.hourlyRateCents)
        minimumHours = pricingModel == .perHour ? max(record.minimumHours ?? 1, 1) : record.minimumHours
        perPersonPriceCents = normalizedPositive(record.perPersonPriceCents)
        minimumGuests = pricingModel == .perPerson ? max(record.minimumGuests ?? 1, 1) : record.minimumGuests
        pricingVisibility = record.pricingVisibility.flatMap(PricingVisibility.init(rawValue:)) ?? .public
        let resolvedSchedule = WeeklySchedule.resolve(
            rawPreset: record.schedulePreset,
            availableDayValues: record.availableDays,
            fallbackAvailabilityMode: record.availabilityMode.flatMap(AvailabilityMode.init(rawValue:))
        )
        schedulePreset = resolvedSchedule.preset
        availableDays = resolvedSchedule.availableDays
        leadTimeDays = min(max(record.leadTimeDays ?? 0, 0), 90)
        advanceBookingDays = min(max(record.advanceBookingDays ?? 180, 7), 365)
        bookingMode = record.bookingMode.flatMap(BookingMode.init(rawValue:)) ?? .inquiryOnly
        paymentMode = record.paymentMode.flatMap(PaymentMode.init(rawValue:)) ?? .external
        cancellationDeadlineDays = record.cancellationDeadlineDays
        schedulingMode = record.schedulingMode
            .flatMap(SchedulingMode.init(rawValue:))
            ?? (record.timeslotsEnabled == true ? .timeslots : .calendar)
        timeslotDurationMinutes = record.timeslotDurationMinutes ?? 60
        timeslotStartHour = record.timeslotStartHour ?? 9
        timeslotStartMinute = record.timeslotStartMinute ?? 0
        timeslotEndHour = record.timeslotEndHour ?? 17
        timeslotEndMinute = record.timeslotEndMinute ?? 0
        timeslotBufferMinutes = record.timeslotBufferMinutes ?? 0
        timeslotRollingWindowDays = record.timeslotRollingWindowDays ?? 14
        timeslotTimezone = record.timeslotTimezone ?? TimeZone.current.identifier
        phone = record.phone ?? ""
        website = record.website ?? ""
        instagramHandle = record.instagramHandle ?? ""
        tiktokHandle = record.tiktokHandle ?? ""
        tags = record.tags ?? []
        collectsGuestCount = record.collectsGuestCount ?? category.defaultCollectsGuestCount
        categoryDetails = record.categoryDetails
        services = record.services ?? []
        leadIntakeQuestions = LeadIntakeTemplateLibrary.resolvedQuestions(for: category, stored: record.leadIntakeQuestions)
        policies = record.policies ?? []
        self.serviceItems = serviceItems.sorted { $0.displayOrder < $1.displayOrder }
        self.packages = packages.sorted { $0.displayOrder < $1.displayOrder }
        self.addOns = addOns.sorted { $0.displayOrder < $1.displayOrder }
        self.pricingImagePaths = record.pricingImageURLs ?? []
        self.galleryImages = galleryImages.sorted { $0.displayOrder < $1.displayOrder }
    }

    func makeRecord(userID: UUID, onboardedAt: Date? = .now) -> VendorProfileRecord {
        VendorProfileRecord(
            userID: userID,
            businessName: businessName.trimmed,
            businessEmail: businessEmail.trimmed.nilIfEmpty,
            profileImagePath: profileImagePath,
            listingImagePath: listingImagePath,
            category: category.rawValue,
            customCategoryName: customCategoryName.trimmed.nilIfEmpty,
            bio: bio.trimmed.nilIfEmpty,
            styleSummary: styleSummary.trimmed.nilIfEmpty,
            city: city.trimmed.nilIfEmpty,
            serviceArea: serviceArea.trimmed.nilIfEmpty,
            startingPrice: displayPriceLabel ?? startingPrice.trimmed.nilIfEmpty,
            pricingModel: pricingModel.rawValue,
            basePriceCents: computedBasePriceCents,
            hourlyRateCents: pricingModel == .perHour ? normalizedPositive(hourlyRateCents) : nil,
            minimumHours: pricingModel == .perHour ? max(minimumHours ?? 1, 1) : nil,
            perPersonPriceCents: pricingModel == .perPerson ? normalizedPositive(perPersonPriceCents) : nil,
            minimumGuests: pricingModel == .perPerson ? max(minimumGuests ?? 1, 1) : nil,
            pricingVisibility: pricingVisibility.rawValue,
            availabilityMode: availabilityMode.rawValue,
            availableDays: weeklySchedule.availableDays.sorted().map(\.rawValue),
            schedulePreset: weeklySchedule.preset.rawValue,
            leadTimeDays: min(max(leadTimeDays, 0), 90),
            advanceBookingDays: min(max(advanceBookingDays, 7), 365),
            bookingMode: bookingMode.rawValue,
            paymentMode: paymentMode.rawValue,
            collectsGuestCount: collectsGuestCount,
            cancellationDeadlineDays: cancellationDeadlineDays,
            phone: phone.trimmed.nilIfEmpty,
            website: website.trimmed.nilIfEmpty,
            instagramHandle: instagramHandle.trimmed.nilIfEmpty,
            tiktokHandle: tiktokHandle.trimmed.nilIfEmpty,
            services: services.map(\.trimmed).filter { !$0.isEmpty },
            categoryDetails: categoryDetails,
            leadIntakeQuestions: leadIntakeQuestions.map { $0.normalized() },
            policies: policies,
            schedulingMode: schedulingMode.rawValue,
            timeslotsEnabled: schedulingMode == .timeslots,
            timeslotDurationMinutes: timeslotDurationMinutes,
            timeslotStartHour: timeslotStartHour,
            timeslotStartMinute: timeslotStartMinute,
            timeslotEndHour: timeslotEndHour,
            timeslotEndMinute: timeslotEndMinute,
            timeslotBufferMinutes: timeslotBufferMinutes,
            timeslotRollingWindowDays: timeslotRollingWindowDays,
            timeslotTimezone: timeslotTimezone,
            pricingImageURLs: pricingImagePaths.isEmpty ? nil : pricingImagePaths,
            profileCompleteness: profileCompleteness,
            tags: tags.map(\.trimmed).filter { !$0.isEmpty },
            onboardedAt: onboardedAt
        )
    }

    private func normalizedPositive(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private static func currencyLabel(forCents cents: Int) -> String {
        let dollars = max(Int((Double(cents) / 100).rounded()), 0)
        return "$\(dollars.formatted())"
    }

    private static func legacyPriceCents(from value: String?) -> Int? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased().replacingOccurrences(of: ",", with: "")
        let multiplier: Double = normalized.contains("k") ? 1_000 : 1
        let numericCharacters = normalized.filter { $0.isNumber || $0 == "." }

        guard let numericValue = Double(numericCharacters), numericValue > 0 else { return nil }
        return Int((numericValue * multiplier * 100).rounded())
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        trimmed.isEmpty ? nil : trimmed
    }
}
