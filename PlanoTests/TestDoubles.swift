import Foundation
@testable import Plano

enum FixtureData {
    static let hostID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    static let vendorID = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    static let secondVendorID = UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!
    static let thirdVendorID = UUID(uuidString: "00000000-0000-0000-0000-00000000B003")!
    static let engagementEventID = UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!
    static let cocktailEventID = UUID(uuidString: "00000000-0000-0000-0000-00000000E002")!
    static let conversationID = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!

    static var events: [PartyEvent] {
        [
            PartyEvent(
                id: engagementEventID,
                title: "Garden Engagement Dinner",
                type: .engagement,
                date: Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now,
                venue: "Maison North",
                city: "Toronto",
                guestCount: 50,
                budgetLabel: "$10k - $16k",
                planningNote: "Need calm, fast-moving vendor decisions.",
                progress: 0.22,
                stage: .requested,
                eventStage: .planning
            ),
            PartyEvent(
                id: cocktailEventID,
                title: "Cocktail Night",
                type: .cocktailNight,
                date: Calendar.current.date(byAdding: .day, value: 45, to: .now) ?? .now,
                venue: "The Atrium",
                city: "Toronto",
                guestCount: 90,
                budgetLabel: "$14k - $22k",
                planningNote: "Music, venue flow, and fast hospitality are the priorities.",
                progress: 0.3,
                stage: .requested,
                eventStage: .planning
            ),
        ]
    }

    static var vendorProfiles: [VendorProfile] {
        [
            VendorProfileRecord(
                userID: vendorID,
                businessName: "Studio Petal",
                category: VendorCategory.decorator.rawValue,
                bio: "Romantic floral and styling direction for intimate events.",
                styleSummary: "Romantic floral styling with restrained tablescapes.",
                city: "Toronto",
                serviceArea: "Toronto + GTA",
                startingPrice: "$2,800 per event",
                pricingModel: PricingModel.perEvent.rawValue,
                basePriceCents: 280_000,
                pricingVisibility: PricingVisibility.public.rawValue,
                availabilityMode: AvailabilityMode.showCalendar.rawValue,
                bookingMode: BookingMode.requestOnly.rawValue,
                paymentMode: PaymentMode.external.rawValue,
                phone: "416-555-0100",
                website: "studiopetal.example",
                instagramHandle: "studiopetal",
                services: ["Floral design", "Tablescape styling"],
                profileCompleteness: 92,
                tags: ["romantic", "garden", "editorial"],
                onboardedAt: .now
            )
            .makeVendorProfile(
                responseTime: "",
                ratingValue: 0.0,
                reviewCount: 0,
                badge: "Fast replies",
                availability: .available,
                services: ["Floral design", "Tablescape styling"],
                packages: [
                    VendorPackage(
                        title: "Floral styling",
                        priceLabel: "$3.5k",
                        summary: "Floral direction and installation for a dinner-scale event.",
                        includedItems: ["Install", "Centerpieces", "Candles"]
                    )
                ],
                reviewHighlights: [
                    VendorReviewEntry(author: "Maya", eventTypeLabel: "Engagement", timelineLabel: "2 weeks ago", rating: 5, quote: "Calm communication and strong execution.")
                ],
                availabilitySummary: VendorAvailabilitySummary(
                    nextOpeningLabel: "Open next week",
                    leadTimeLabel: "2 weeks lead time",
                    eventDateSupportLabel: "Available for your selected date.",
                    supportsSelectedEventDate: true,
                    windows: [AvailabilityWindow(label: "Selected date", state: .open)]
                ),
                repeatBookingRateLabel: "Booked repeatedly",
                searchMomentumScore: 91
            ),
            VendorProfileRecord(
                userID: secondVendorID,
                businessName: "North Frame",
                category: VendorCategory.photographer.rawValue,
                bio: "Documentary-style photography for events.",
                styleSummary: "Soft flash, movement, and editorial portraits.",
                city: "Toronto",
                serviceArea: "Toronto + GTA",
                startingPrice: "From $4,200",
                pricingModel: PricingModel.startingFrom.rawValue,
                basePriceCents: 420_000,
                pricingVisibility: PricingVisibility.public.rawValue,
                availabilityMode: AvailabilityMode.showCalendar.rawValue,
                bookingMode: BookingMode.requestOnly.rawValue,
                paymentMode: PaymentMode.external.rawValue,
                services: ["Event coverage", "Portraits"],
                profileCompleteness: 88,
                tags: ["editorial", "soft flash"],
                onboardedAt: .now
            )
            .makeVendorProfile(
                responseTime: "",
                ratingValue: 0.0,
                reviewCount: 0,
                badge: "Editorial",
                availability: .available,
                services: ["Event coverage", "Portraits"],
                packages: [],
                reviewHighlights: [],
                availabilitySummary: VendorAvailabilitySummary(
                    nextOpeningLabel: "Open next month",
                    leadTimeLabel: "3 weeks lead time",
                    eventDateSupportLabel: "Available for your selected date.",
                    supportsSelectedEventDate: true,
                    windows: [AvailabilityWindow(label: "Selected date", state: .open)]
                ),
                repeatBookingRateLabel: "Steady rebooks",
                searchMomentumScore: 82
            ),
            VendorProfileRecord(
                userID: thirdVendorID,
                businessName: "Afterglow DJ Co.",
                category: VendorCategory.dj.rawValue,
                bio: "Party-first DJ sets for birthdays, socials, and fast-moving dance floors.",
                styleSummary: "Open-format music direction with clean transitions and crowd reading.",
                city: "Toronto",
                serviceArea: "Toronto + GTA",
                startingPrice: "$125/hr (4 hr min)",
                pricingModel: PricingModel.perHour.rawValue,
                basePriceCents: 50_000,
                hourlyRateCents: 12_500,
                minimumHours: 4,
                pricingVisibility: PricingVisibility.public.rawValue,
                availabilityMode: AvailabilityMode.showCalendar.rawValue,
                bookingMode: BookingMode.requestOnly.rawValue,
                paymentMode: PaymentMode.external.rawValue,
                services: ["DJ set", "MC support"],
                profileCompleteness: 80,
                tags: ["birthday", "dance floor", "open format"],
                onboardedAt: .now
            )
            .makeVendorProfile(
                responseTime: "",
                ratingValue: 0.0,
                reviewCount: 0,
                badge: "Birthday favorite",
                availability: .bookingFast,
                services: ["DJ set", "MC support"],
                packages: [
                    VendorPackage(
                        title: "Starter set",
                        priceLabel: "$550",
                        summary: "Four-hour music coverage with MC support for birthday and shower events.",
                        tier: .starter,
                        includedItems: ["4 hours", "MC support", "Basic lighting"]
                    )
                ],
                reviewHighlights: [],
                availabilitySummary: VendorAvailabilitySummary(
                    nextOpeningLabel: "Open this month",
                    leadTimeLabel: "10 days lead time",
                    eventDateSupportLabel: "Available for your selected date.",
                    supportsSelectedEventDate: true,
                    windows: [AvailabilityWindow(label: "Selected date", state: .open)]
                ),
                repeatBookingRateLabel: "Good rebook pace",
                searchMomentumScore: 76
            ),
        ]
    }

    static func anonymousSession(name: String? = nil) -> AnonymousHostSession {
        AnonymousHostSession(
            userID: hostID,
            displayName: name,
            contactPhone: nil,
            contactEmail: nil,
            isLinkedToApple: false,
            emailAddress: nil
        )
    }

    static var vendorSession: AuthenticatedUserProfile {
        AuthenticatedUserProfile(
            userID: vendorID,
            emailAddress: "vendor@example.com",
            displayName: "Vendor User",
            vendorDisplayName: "Studio Petal"
        )
    }

    static var sampleInsights: VendorInsightsRecord {
        VendorInsightsRecord(
            discovery: .init(
                profileViews: 142,
                profileViewsTrend: 12.5,
                uniqueViewers: 98,
                searchImpressions: 890,
                searchImpressionsTrend: 8.2,
                clickThroughRate: 0.16,
                clickThroughRateTrend: 3.1,
                topSearchQueries: [
                    .init(query: "toronto photographer", count: 34),
                    .init(query: "wedding photographer", count: 22),
                    .init(query: "event photography", count: 15),
                ],
                avgSearchPosition: 3.2
            ),
            engagement: .init(
                saveCount: 18,
                saveRate: 0.127,
                saveRateTrend: -2.3,
                galleryEngagements: 67,
                socialLinkClicks: 12
            ),
            conversion: .init(
                messageInitiationRate: 0.085,
                messageInitiationRateTrend: 5.1,
                bookingRequestRate: 0.042,
                bookingRequestRateTrend: -1.2,
                leadToBookingConversion: 0.65,
                leadToBookingConversionTrend: 8.4,
                avgResponseMinutes: 45.0,
                avgResponseMinutesTrend: -12.0,
                conversationsStarted: 12,
                bookingsRequested: 6,
                bookingsConfirmed: 4
            ),
            revenue: .init(
                totalRevenueCents: 425000,
                totalRevenueTrend: 15.2,
                avgBookingValueCents: 106250,
                avgBookingValueTrend: 3.8,
                bookingVolume: 4,
                bookingVolumeTrend: 33.3
            ),
            benchmarks: .init(
                category: "photographer",
                categoryAvgResponseMinutes: 72.0,
                categoryAvgConversionRate: 0.48,
                categoryAvgProfileViews: 95.0,
                categoryMedianRating: 4.7,
                categoryVendorCount: 156
            )
        )
    }

    static func conversationRecord(event: PartyEvent = FixtureData.events[0]) -> ConversationRecord {
        ConversationRecord(
            id: conversationID,
            eventID: event.id,
            vendorID: vendorID,
            hostID: hostID,
            hostDisplayName: "Maya Chen",
            vendorDisplayName: "Studio Petal",
            vendorCategory: VendorCategory.decorator.rawValue,
            eventTitle: event.title,
            eventDateLabel: event.formattedDate,
            eventContextLine: event.contextLine,
            stage: BookingStage.requested.rawValue,
            lastActivityAt: .now,
            createdAt: .now,
            updatedAt: .now,
            hostUnreadCount: nil,
            vendorUnreadCount: nil
        )
    }
}

actor TestAuthService: AuthServiceProtocol {
    var restoredSession: RestoredAuthSession?

    init(restoredSession: RestoredAuthSession? = .anonymous(FixtureData.anonymousSession())) {
        self.restoredSession = restoredSession
    }

    func restoreSession() async throws -> RestoredAuthSession? {
        restoredSession
    }

    func signInAnonymously() async throws -> AnonymousHostSession {
        let session = FixtureData.anonymousSession()
        restoredSession = .anonymous(session)
        return session
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        restoredSession = .authenticated(FixtureData.vendorSession)
        return FixtureData.vendorSession
    }

    func setHostIdentity(
        name: String,
        phone: String?,
        email: String?
    ) async throws -> AnonymousHostSession {
        let session = AnonymousHostSession(
            userID: FixtureData.hostID,
            displayName: name,
            contactPhone: phone,
            contactEmail: email,
            isLinkedToApple: false,
            emailAddress: email
        )
        restoredSession = .anonymous(session)
        return session
    }

    func upgradeAnonymousToApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        let profile = AuthenticatedUserProfile(
            userID: FixtureData.hostID,
            emailAddress: email,
            displayName: givenName.map { name in
                [name, familyName].compactMap { $0 }.joined(separator: " ")
            } ?? "Maya Chen",
            vendorDisplayName: nil
        )
        restoredSession = .authenticated(profile)
        return profile
    }

    func signUpWithEmail(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> AuthenticatedUserProfile {
        let profile = AuthenticatedUserProfile(
            userID: FixtureData.hostID,
            emailAddress: email,
            displayName: displayName ?? "Plano User",
            vendorDisplayName: nil
        )
        restoredSession = .authenticated(profile)
        return profile
    }

    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUserProfile {
        let profile = AuthenticatedUserProfile(
            userID: FixtureData.hostID,
            emailAddress: email,
            displayName: "Plano User",
            vendorDisplayName: nil
        )
        restoredSession = .authenticated(profile)
        return profile
    }

    func signOut() async throws {
        restoredSession = .anonymous(FixtureData.anonymousSession())
    }

    func deleteAccount() async throws -> DeletionResult {
        restoredSession = .anonymous(FixtureData.anonymousSession())
        return DeletionResult(cancelledBookings: 0)
    }
}

actor TestEventService: EventServiceProtocol {
    var events: [PartyEvent]

    init(events: [PartyEvent] = FixtureData.events) {
        self.events = events
    }

    func fetchEvents() async throws -> [PartyEvent] {
        events
    }

    func createEvent(from draft: EventDraft) async throws -> PartyEvent {
        let event = draft.makeEvent()
        events.append(event)
        return event
    }

    func updateEventVenue(_ venue: String, eventID: UUID) async throws -> PartyEvent {
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            throw APIError.invalidResponse
        }

        events[index].venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        return events[index]
    }

    func deleteEvent(eventID: UUID) async throws -> DeletionResult {
        events.removeAll { $0.id == eventID }
        return DeletionResult(cancelledBookings: 0)
    }
}

actor TestVendorSearchService: VendorSearchServiceProtocol {
    var vendorProfiles: [VendorProfile]
    var savedVendorIDs: Set<UUID> = []

    init(vendorProfiles: [VendorProfile] = FixtureData.vendorProfiles) {
        self.vendorProfiles = vendorProfiles
    }

    func searchVendors(matching request: VendorSearchRequest) async throws -> [VendorProfileRecord] {
        return vendorProfiles
            .filter { vendor in
                let matchesCategory = request.category.map { vendor.category == $0 } ?? true
                guard !request.searchTokens.isEmpty else {
                    return matchesCategory
                }

                let haystack = [
                    vendor.businessName,
                    vendor.styleSummary,
                    vendor.city,
                    vendor.serviceArea,
                    vendor.category.title,
                    vendor.category.singularTitle,
                    vendor.category.searchKeywords.joined(separator: " "),
                    vendor.tags.joined(separator: " "),
                ]
                .joined(separator: " ")
                .localizedLowercase

                return matchesCategory && request.tokenMatchScore(in: haystack) >= request.minimumTokenMatches
            }
            .map(VendorProfileRecord.init(profile:))
    }

    func fetchSavedVendorIDs() async throws -> Set<UUID> {
        savedVendorIDs
    }

    func saveVendor(_ vendorID: UUID) async throws {
        savedVendorIDs.insert(vendorID)
    }

    func unsaveVendor(_ vendorID: UUID) async throws {
        savedVendorIDs.remove(vendorID)
    }
}

actor TestVendorProfileService: VendorProfileServiceProtocol {
    var profilesByID: [UUID: VendorProfile]
    var serviceItemsByVendorID: [UUID: [VendorServiceItem]]

    init(vendorProfiles: [VendorProfile] = FixtureData.vendorProfiles) {
        profilesByID = Dictionary(uniqueKeysWithValues: vendorProfiles.map { ($0.id, $0) })
        serviceItemsByVendorID = Dictionary(uniqueKeysWithValues: vendorProfiles.map { ($0.id, $0.serviceItems) })
    }

    func createVendorProfile(
        businessName: String,
        businessEmail: String?,
        category: VendorCategory,
        city: String?
    ) async throws -> VendorProfileRecord {
        let record = VendorProfileRecord(
            userID: FixtureData.vendorID,
            businessName: businessName,
            businessEmail: businessEmail,
            category: category.rawValue,
            city: city,
            profileCompleteness: 20,
            onboardedAt: .now
        )
        profilesByID[FixtureData.vendorID] = record.makeVendorProfile()
        serviceItemsByVendorID[FixtureData.vendorID] = []
        return record
    }

    func fetchOwnVendorProfile() async throws -> VendorProfileRecord? {
        profilesByID[FixtureData.vendorID].map(VendorProfileRecord.init(profile:))
    }

    func fetchPublicVendorProfile(vendorID: UUID) async throws -> VendorProfileRecord? {
        profilesByID[vendorID].map(VendorProfileRecord.init(profile:))
    }

    func updateVendorProfile(_ updates: VendorProfileRecord) async throws -> VendorProfileRecord {
        let existing = profilesByID[updates.userID]
        let serviceItems = serviceItemsByVendorID[updates.userID] ?? existing?.serviceItems ?? []

        profilesByID[updates.userID] = updates.makeVendorProfile(
            responseTime: existing?.responseTime ?? "",
            ratingValue: existing?.ratingValue ?? 0.0,
            reviewCount: existing?.reviewCount ?? 0,
            badge: existing?.badge ?? "Fresh profile",
            intro: existing?.intro ?? updates.bio,
            availability: existing?.availability ?? .bookingFast,
            services: updates.services ?? existing?.services ?? [],
            serviceItems: serviceItems,
            packages: existing?.packages ?? [],
            galleryImages: existing?.galleryImages ?? [],
            review: existing?.review ?? VendorReviewSnippet(
                author: "Recent host",
                eventTypeLabel: "Private event",
                quote: "Clear communication and a calm booking process."
            ),
            reviewHighlights: existing?.reviewHighlights ?? [],
            availabilitySummary: existing?.availabilitySummary ?? VendorAvailabilitySummary(
                nextOpeningLabel: "Availability on request",
                leadTimeLabel: "Lead time varies",
                eventDateSupportLabel: "Availability is confirmed after the request is reviewed.",
                supportsSelectedEventDate: true,
                windows: []
            ),
            repeatBookingRateLabel: existing?.repeatBookingRateLabel ?? "New listing",
            searchMomentumScore: existing?.searchMomentumScore ?? 72
        )
        return updates
    }

    func fetchGalleryImages(vendorID: UUID) async throws -> [VendorGalleryImage] {
        profilesByID[vendorID]?.galleryImages ?? []
    }

    func replaceGalleryImages(_ images: [VendorGalleryImage], vendorID: UUID) async throws {
        guard let existing = profilesByID[vendorID] else { return }

        profilesByID[vendorID] = VendorProfile(
            id: existing.id,
            businessName: existing.businessName,
            category: existing.category,
            customCategoryName: existing.customCategoryName,
            bio: existing.bio,
            city: existing.city,
            serviceArea: existing.serviceArea,
            startingPrice: existing.startingPrice,
            pricingModel: existing.pricingModel,
            basePriceCents: existing.basePriceCents,
            hourlyRateCents: existing.hourlyRateCents,
            minimumHours: existing.minimumHours,
            perPersonPriceCents: existing.perPersonPriceCents,
            minimumGuests: existing.minimumGuests,
            pricingVisibility: existing.pricingVisibility,
            weeklySchedule: existing.weeklySchedule,
            leadTimeDays: existing.leadTimeDays,
            advanceBookingDays: existing.advanceBookingDays,
            availabilityMode: existing.availabilityMode,
            bookingMode: existing.bookingMode,
            paymentMode: existing.paymentMode,
            phone: existing.phone,
            website: existing.website,
            instagramHandle: existing.instagramHandle,
            tiktokHandle: existing.tiktokHandle,
            tags: existing.tags,
            responseTime: existing.responseTime,
            ratingValue: existing.ratingValue,
            reviewCount: existing.reviewCount,
            badge: existing.badge,
            intro: existing.intro,
            styleSummary: existing.styleSummary,
            availability: existing.availability,
            services: existing.services,
            serviceItems: existing.serviceItems,
            packages: existing.packages,
            galleryHighlights: images.sorted { $0.displayOrder < $1.displayOrder }.compactMap { image in
                let trimmed = image.caption.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            },
            galleryImages: images,
            review: existing.review,
            reviewHighlights: existing.reviewHighlights,
            availabilitySummary: existing.availabilitySummary,
            repeatBookingRateLabel: existing.repeatBookingRateLabel,
            profileCompleteness: existing.profileCompleteness,
            searchMomentumScore: existing.searchMomentumScore,
            onboardedAt: existing.onboardedAt
        )
    }

    func fetchServiceItems(vendorID: UUID) async throws -> [VendorServiceItem] {
        serviceItemsByVendorID[vendorID] ?? []
    }

    func replaceServiceItems(_ items: [VendorServiceItem], vendorID: UUID) async throws {
        let normalizedItems = items.enumerated().map { index, item in
            VendorServiceItem(
                id: item.id,
                title: item.title,
                priceCents: item.priceCents,
                description: item.description,
                displayOrder: index
            )
        }

        serviceItemsByVendorID[vendorID] = normalizedItems

        guard let existing = profilesByID[vendorID] else { return }
        profilesByID[vendorID] = VendorProfile(
            id: existing.id,
            businessName: existing.businessName,
            category: existing.category,
            customCategoryName: existing.customCategoryName,
            bio: existing.bio,
            city: existing.city,
            serviceArea: existing.serviceArea,
            startingPrice: existing.startingPrice,
            pricingModel: existing.pricingModel,
            basePriceCents: existing.basePriceCents,
            hourlyRateCents: existing.hourlyRateCents,
            minimumHours: existing.minimumHours,
            perPersonPriceCents: existing.perPersonPriceCents,
            minimumGuests: existing.minimumGuests,
            pricingVisibility: existing.pricingVisibility,
            weeklySchedule: existing.weeklySchedule,
            leadTimeDays: existing.leadTimeDays,
            advanceBookingDays: existing.advanceBookingDays,
            availabilityMode: existing.availabilityMode,
            bookingMode: existing.bookingMode,
            paymentMode: existing.paymentMode,
            phone: existing.phone,
            website: existing.website,
            instagramHandle: existing.instagramHandle,
            tiktokHandle: existing.tiktokHandle,
            tags: existing.tags,
            responseTime: existing.responseTime,
            ratingValue: existing.ratingValue,
            reviewCount: existing.reviewCount,
            badge: existing.badge,
            intro: existing.intro,
            styleSummary: existing.styleSummary,
            availability: existing.availability,
            services: existing.services,
            serviceItems: normalizedItems,
            packages: existing.packages,
            galleryHighlights: existing.galleryHighlights,
            galleryImages: existing.galleryImages,
            review: existing.review,
            reviewHighlights: existing.reviewHighlights,
            availabilitySummary: existing.availabilitySummary,
            repeatBookingRateLabel: existing.repeatBookingRateLabel,
            profileCompleteness: existing.profileCompleteness,
            searchMomentumScore: existing.searchMomentumScore,
            onboardedAt: existing.onboardedAt
        )
    }

    func deleteVendorListing() async throws -> DeletionResult {
        DeletionResult(cancelledBookings: 0)
    }
}

actor TestBookingService: BookingServiceProtocol {
    var conversations: [ConversationRecord]
    var messagesByConversation: [UUID: [MessageRecord]]
    var bookingRequests: [BookingRequestRecord]
    var bookings: [BookingRecord]

    init(
        conversations: [ConversationRecord] = [],
        messagesByConversation: [UUID: [MessageRecord]] = [:],
        bookingRequests: [BookingRequestRecord] = [],
        bookings: [BookingRecord] = []
    ) {
        self.conversations = conversations
        self.messagesByConversation = messagesByConversation
        self.bookingRequests = bookingRequests
        self.bookings = bookings
    }

    func fetchConversations(hostID: UUID) async throws -> [ConversationRecord] {
        conversations.filter { $0.hostID == hostID }
    }

    func fetchVendorConversations(vendorID: UUID) async throws -> [ConversationRecord] {
        conversations.filter { $0.vendorID == vendorID }
    }

    func createConversation(vendorID: UUID, hostID: UUID, eventID: UUID?) async throws -> ConversationRecord {
        let event = FixtureData.events.first(where: { $0.id == eventID })
        let record = ConversationRecord(
            id: UUID(),
            eventID: eventID,
            vendorID: vendorID,
            hostID: hostID,
            hostDisplayName: "Maya Chen",
            vendorDisplayName: FixtureData.vendorProfiles.first(where: { $0.id == vendorID })?.businessName ?? "Vendor",
            vendorCategory: FixtureData.vendorProfiles.first(where: { $0.id == vendorID })?.category.rawValue ?? VendorCategory.entertainer.rawValue,
            eventTitle: event?.title,
            eventDateLabel: event?.formattedDate,
            eventContextLine: event?.contextLine,
            stage: BookingStage.active.rawValue,
            lastActivityAt: .now,
            createdAt: .now,
            updatedAt: .now,
            hostUnreadCount: nil,
            vendorUnreadCount: nil
        )
        conversations.append(record)
        messagesByConversation[record.id] = []
        return record
    }

    func fetchMessages(conversationID: UUID) async throws -> [MessageRecord] {
        messagesByConversation[conversationID] ?? []
    }

    func sendMessage(conversationID: UUID, body: String, kind: String, senderRole: String) async throws -> MessageRecord {
        let record = MessageRecord(
            id: UUID(),
            conversationID: conversationID,
            senderRole: senderRole,
            body: body,
            kind: kind,
            createdAt: .now
        )
        messagesByConversation[conversationID, default: []].append(record)
        return record
    }

    func fetchBookingRequests(conversationIDs: [UUID]) async throws -> [BookingRequestRecord] {
        bookingRequests.filter { conversationIDs.contains($0.conversationID) }
    }

    func fetchBookings(conversationIDs: [UUID]) async throws -> [BookingRecord] {
        bookings.filter { conversationIDs.contains($0.conversationID) }
    }

    func fetchHostBookings(hostID: UUID) async throws -> [BookingRecord] {
        bookings.filter { $0.hostID == hostID }
    }

    func fetchVendorBookings(vendorID: UUID) async throws -> [BookingRecord] {
        bookings.filter { $0.vendorID == vendorID }
    }

    func submitBookingRequest(
        conversationID: UUID,
        eventDate: Date,
        note: String,
        requestedTimeStart: String?,
        requestedTimeEnd: String?,
        title: String?,
        budgetLabel: String?,
        guestCountLabel: String?,
        requestedServices: [String]?
    ) async throws -> BookingTransitionResult {
        let conversation = try conversationRecord(for: conversationID)
        let request = BookingRequestRecord(
            id: UUID(),
            conversationID: conversationID,
            title: title,
            budgetLabel: budgetLabel,
            requestedServices: requestedServices,
            note: note,
            guestCountLabel: guestCountLabel,
            eventDate: eventDate,
            createdAt: .now
        )
        bookingRequests.append(request)
        ensureBooking(for: conversation, stage: BookingStage.requested.rawValue)
        updateConversationStage(conversationID, stage: BookingStage.requested.rawValue)
        return BookingTransitionResult(
            conversationID: conversationID,
            stage: BookingStage.requested.rawValue,
            bookingID: bookings.first(where: { $0.conversationID == conversationID })?.id,
            dateConflicts: nil
        )
    }

    func acceptBooking(conversationID: UUID) async throws -> BookingTransitionResult {
        if let index = bookings.firstIndex(where: { $0.conversationID == conversationID }) {
            let current = bookings[index]
            bookings[index] = BookingRecord(
                id: current.id,
                conversationID: current.conversationID,
                eventID: current.eventID,
                vendorID: current.vendorID,
                hostID: current.hostID,
                eventDate: current.eventDate,
                stage: BookingStage.accepted.rawValue,
                createdAt: current.createdAt,
                updatedAt: .now
            )
        }
        updateConversationStage(conversationID, stage: BookingStage.accepted.rawValue)
        return BookingTransitionResult(
            conversationID: conversationID,
            stage: BookingStage.accepted.rawValue,
            bookingID: bookings.first(where: { $0.conversationID == conversationID })?.id,
            dateConflicts: nil
        )
    }

    func requestPayment(conversationID: UUID, amountCents: Int, note: String?, paymentType: String?) async throws -> BookingTransitionResult {
        if let index = bookings.firstIndex(where: { $0.conversationID == conversationID }) {
            let current = bookings[index]
            bookings[index] = BookingRecord(
                id: current.id,
                conversationID: current.conversationID,
                eventID: current.eventID,
                vendorID: current.vendorID,
                hostID: current.hostID,
                eventDate: current.eventDate,
                paymentRequestedAmountCents: amountCents,
                paymentRequestedAt: .now,
                paymentType: paymentType,
                stage: BookingStage.paymentRequested.rawValue,
                createdAt: current.createdAt,
                updatedAt: .now
            )
        }
        updateConversationStage(conversationID, stage: BookingStage.paymentRequested.rawValue)
        return BookingTransitionResult(
            conversationID: conversationID,
            stage: BookingStage.paymentRequested.rawValue,
            bookingID: bookings.first(where: { $0.conversationID == conversationID })?.id,
            dateConflicts: nil
        )
    }

    func confirmPayment(conversationID: UUID) async throws -> BookingTransitionResult {
        if let index = bookings.firstIndex(where: { $0.conversationID == conversationID }) {
            let current = bookings[index]
            bookings[index] = BookingRecord(
                id: current.id,
                conversationID: current.conversationID,
                eventID: current.eventID,
                vendorID: current.vendorID,
                hostID: current.hostID,
                eventDate: current.eventDate,
                paymentRequestedAmountCents: current.paymentRequestedAmountCents,
                paymentRequestedAt: current.paymentRequestedAt,
                paymentConfirmedAt: .now,
                stage: BookingStage.paid.rawValue,
                createdAt: current.createdAt,
                updatedAt: .now
            )
        }
        updateConversationStage(conversationID, stage: BookingStage.paid.rawValue)
        return BookingTransitionResult(
            conversationID: conversationID,
            stage: BookingStage.paid.rawValue,
            bookingID: bookings.first(where: { $0.conversationID == conversationID })?.id,
            dateConflicts: nil
        )
    }

    func vendorConfirmPayment(conversationID: UUID) async throws -> BookingTransitionResult {
        if let index = bookings.firstIndex(where: { $0.conversationID == conversationID }) {
            let current = bookings[index]
            bookings[index] = BookingRecord(
                id: current.id,
                conversationID: current.conversationID,
                eventID: current.eventID,
                vendorID: current.vendorID,
                hostID: current.hostID,
                eventDate: current.eventDate,
                paymentRequestedAmountCents: current.paymentRequestedAmountCents,
                paymentRequestedAt: current.paymentRequestedAt,
                paymentConfirmedAt: .now,
                stage: BookingStage.paid.rawValue,
                createdAt: current.createdAt,
                updatedAt: .now
            )
        }
        updateConversationStage(conversationID, stage: BookingStage.paid.rawValue)
        return BookingTransitionResult(
            conversationID: conversationID,
            stage: BookingStage.paid.rawValue,
            bookingID: bookings.first(where: { $0.conversationID == conversationID })?.id,
            dateConflicts: nil
        )
    }

    func declineBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult {
        if let index = bookings.firstIndex(where: { $0.conversationID == conversationID }) {
            let current = bookings[index]
            bookings[index] = BookingRecord(
                id: current.id,
                conversationID: current.conversationID,
                eventID: current.eventID,
                vendorID: current.vendorID,
                hostID: current.hostID,
                eventDate: current.eventDate,
                cancellationReason: reason,
                stage: BookingStage.declined.rawValue,
                createdAt: current.createdAt,
                updatedAt: .now
            )
        }
        updateConversationStage(conversationID, stage: BookingStage.declined.rawValue)
        return BookingTransitionResult(
            conversationID: conversationID,
            stage: BookingStage.declined.rawValue,
            bookingID: bookings.first(where: { $0.conversationID == conversationID })?.id,
            dateConflicts: nil
        )
    }

    func cancelBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult {
        if let index = bookings.firstIndex(where: { $0.conversationID == conversationID }) {
            let current = bookings[index]
            bookings[index] = BookingRecord(
                id: current.id,
                conversationID: current.conversationID,
                eventID: current.eventID,
                vendorID: current.vendorID,
                hostID: current.hostID,
                eventDate: current.eventDate,
                cancelledBy: current.hostID,
                cancelledAt: .now,
                cancellationReason: reason,
                stage: BookingStage.cancelled.rawValue,
                createdAt: current.createdAt,
                updatedAt: .now
            )
        }
        updateConversationStage(conversationID, stage: BookingStage.cancelled.rawValue)
        return BookingTransitionResult(
            conversationID: conversationID,
            stage: BookingStage.cancelled.rawValue,
            bookingID: bookings.first(where: { $0.conversationID == conversationID })?.id,
            dateConflicts: nil
        )
    }

    func respondToCancellationRequest(conversationID: UUID, approved: Bool, reason: String?) async throws -> BookingTransitionResult {
        let newStage = approved ? BookingStage.cancelled : BookingStage.accepted
        updateConversationStage(conversationID, stage: newStage.rawValue)
        return BookingTransitionResult(
            conversationID: conversationID,
            stage: newStage.rawValue,
            bookingID: bookings.first(where: { $0.conversationID == conversationID })?.id,
            dateConflicts: nil
        )
    }

    func forceCancelBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult {
        if let index = bookings.firstIndex(where: { $0.conversationID == conversationID }) {
            let current = bookings[index]
            bookings[index] = BookingRecord(
                id: current.id,
                conversationID: current.conversationID,
                eventID: current.eventID,
                vendorID: current.vendorID,
                hostID: current.hostID,
                eventDate: current.eventDate,
                cancelledBy: current.cancellationRequestedBy ?? current.hostID,
                cancelledAt: .now,
                cancellationReason: reason,
                forceCancelled: true,
                stage: BookingStage.cancelled.rawValue,
                createdAt: current.createdAt,
                updatedAt: .now
            )
        }
        updateConversationStage(conversationID, stage: BookingStage.cancelled.rawValue)
        return BookingTransitionResult(
            conversationID: conversationID,
            stage: BookingStage.cancelled.rawValue,
            bookingID: bookings.first(where: { $0.conversationID == conversationID })?.id,
            dateConflicts: nil,
            forceCancelled: true
        )
    }

    func createConversationServer(vendorID: UUID, eventID: UUID?) async throws -> ConversationRecord {
        try await createConversation(vendorID: vendorID, hostID: FixtureData.hostID, eventID: eventID)
    }

    func fetchConversationSummaries(role: String) async throws -> [ConversationSummaryRecord] {
        []
    }

    func linkConversationToEvent(conversationID: UUID, eventID: UUID) async throws {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let current = conversations[index]
        conversations[index] = ConversationRecord(
            id: current.id,
            eventID: eventID,
            vendorID: current.vendorID,
            hostID: current.hostID,
            hostDisplayName: current.hostDisplayName,
            vendorDisplayName: current.vendorDisplayName,
            vendorCategory: current.vendorCategory,
            eventTitle: current.eventTitle,
            eventDateLabel: current.eventDateLabel,
            eventContextLine: current.eventContextLine,
            stage: current.stage,
            lastActivityAt: current.lastActivityAt,
            createdAt: current.createdAt,
            updatedAt: .now,
            hostUnreadCount: current.hostUnreadCount,
            vendorUnreadCount: current.vendorUnreadCount
        )
    }

    func checkVendorDateConflicts(vendorID: UUID, eventDate: Date) async throws -> [DateConflict] {
        try computeDateConflicts(vendorID: vendorID, eventDate: eventDate)
    }

    func fetchEventConfirmedVendors(eventID: UUID, requestingVendorID: UUID) async throws -> [CoBookedVendorRecord] {
        conversations
            .filter { $0.eventID == eventID && $0.stage == BookingStage.paid.rawValue && $0.vendorID != requestingVendorID }
            .map { CoBookedVendorRecord(vendorID: $0.vendorID, vendorDisplayName: $0.vendorDisplayName, vendorCategory: $0.vendorCategory) }
    }

    var vendorNotes: [UUID: String] = [:]

    func fetchVendorNote(conversationID: UUID) async throws -> String? {
        vendorNotes[conversationID]
    }

    func saveVendorNote(conversationID: UUID, content: String) async throws {
        vendorNotes[conversationID] = content
    }

    private func updateConversationStage(_ conversationID: UUID, stage: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let current = conversations[index]
        conversations[index] = ConversationRecord(
            id: current.id,
            eventID: current.eventID,
            vendorID: current.vendorID,
            hostID: current.hostID,
            hostDisplayName: current.hostDisplayName,
            vendorDisplayName: current.vendorDisplayName,
            vendorCategory: current.vendorCategory,
            eventTitle: current.eventTitle,
            eventDateLabel: current.eventDateLabel,
            eventContextLine: current.eventContextLine,
            stage: stage,
            lastActivityAt: .now,
            createdAt: current.createdAt,
            updatedAt: .now,
            hostUnreadCount: current.hostUnreadCount,
            vendorUnreadCount: current.vendorUnreadCount
        )
    }

    private func ensureBooking(for conversation: ConversationRecord, stage: String) {
        guard !bookings.contains(where: { $0.conversationID == conversation.id }) else { return }
        bookings.append(
            BookingRecord(
                id: UUID(),
                conversationID: conversation.id,
                eventID: conversation.eventID,
                vendorID: conversation.vendorID,
                hostID: conversation.hostID,
                eventDate: eventDate(for: conversation.eventID),
                stage: stage,
                createdAt: .now,
                updatedAt: .now
            )
        )
    }

    private func conversationRecord(for conversationID: UUID) throws -> ConversationRecord {
        guard let record = conversations.first(where: { $0.id == conversationID }) else {
            throw APIError.invalidResponse
        }
        return record
    }

    private func eventDate(for eventID: UUID?) -> Date? {
        FixtureData.events.first(where: { $0.id == eventID })?.date
    }

    private func computeDateConflicts(vendorID: UUID, eventDate: Date?) throws -> [DateConflict] {
        guard let eventDate else { return [] }
        let calendar = Calendar.current

        return bookings
            .filter {
                $0.vendorID == vendorID &&
                $0.stage != BookingStage.cancelled.rawValue &&
                $0.stage != BookingStage.declined.rawValue &&
                $0.stage != BookingStage.active.rawValue &&
                $0.eventDate.map { calendar.isDate($0, inSameDayAs: eventDate) } == true
            }
            .compactMap { booking in
                guard let conversation = conversations.first(where: { $0.id == booking.conversationID }) else {
                    return nil
                }

                return DateConflict(
                    conversationID: conversation.id,
                    eventTitle: conversation.eventTitle ?? "Direct inquiry",
                    hostDisplayName: conversation.hostDisplayName,
                    stage: booking.stage
                )
            }
    }
}

struct TestMediaService: MediaServiceProtocol {
    var uploadedPaths: [String] = []

    func uploadImage(data: Data, vendorID: UUID) async throws -> String {
        "mock://vendor-galleries/\(vendorID.uuidString)/\(UUID().uuidString).jpg"
    }

    func uploadImageVariants(_ variants: [ImageSize: Data], vendorID: UUID) async throws -> String {
        "mock://vendor-galleries/\(vendorID.uuidString)/\(UUID().uuidString)"
    }

    func deleteImage(path: String) async throws {}

    func imageURL(for path: String) async throws -> URL {
        URL(string: "https://mock.storage.example/\(path)") ?? URL(string: "https://mock.storage.example/fallback")!
    }

    func imageURL(for path: String, size: ImageSize) async throws -> URL {
        URL(string: "https://mock.storage.example/\(path)_\(size.rawValue)") ?? URL(string: "https://mock.storage.example/fallback")!
    }
}

struct TestAvailabilityService: VendorAvailabilityServiceProtocol {
    var availableVendorIDs: [UUID] = FixtureData.vendorProfiles.map(\.id)

    func fetchAvailability(vendorID: UUID, from: Date, to: Date) async throws -> [VendorAvailabilityRecord] {
        []
    }

    func setAvailability(vendorID: UUID, date: Date, status: String) async throws {}

    func removeAvailability(vendorID: UUID, date: Date) async throws {}

    func vendorsAvailable(on date: Date, category: VendorCategory?, city: String?) async throws -> [UUID] {
        availableVendorIDs
    }

    func checkAvailability(vendorID: UUID, on date: Date) async throws -> VendorDateAvailability {
        VendorDateAvailability(
            vendorID: vendorID,
            date: date,
            isAvailable: availableVendorIDs.contains(vendorID),
            bookedCount: 0,
            capacity: 1,
            checkedAt: .now
        )
    }

    func fetchTimeslotBookings(vendorID: UUID, from: Date, to: Date) async throws -> [VendorTimeslotBookingRecord] {
        []
    }

    func setTimeslotBooking(record: VendorTimeslotBookingRecord) async throws {}

    func removeTimeslotBooking(vendorID: UUID, date: Date, startTime: String) async throws {}
}

actor TestPlannedVendorService: PlannedVendorServiceProtocol {
    var plannedVendors: [PlannedVendorRecord] = []

    func fetchPlannedVendors(eventID: UUID) async throws -> [PlannedVendorRecord] {
        plannedVendors.filter { $0.eventID == eventID && $0.status != PlannedVendorStatus.removed.rawValue }
    }

    func fetchAllPlannedVendors(eventIDs: [UUID]) async throws -> [PlannedVendorRecord] {
        plannedVendors.filter { eventIDs.contains($0.eventID) && $0.status != PlannedVendorStatus.removed.rawValue }
    }

    func planVendor(eventID: UUID, vendorID: UUID, category: VendorCategory) async throws -> PlannedVendorRecord {
        if let index = plannedVendors.firstIndex(where: { $0.eventID == eventID && $0.vendorID == vendorID }) {
            let existing = plannedVendors[index]
            let updated = PlannedVendorRecord(
                id: existing.id,
                eventID: eventID,
                vendorID: vendorID,
                category: category.rawValue,
                status: PlannedVendorStatus.planned.rawValue,
                availabilityCheckedAt: .now
            )
            plannedVendors[index] = updated
            return updated
        }

        let record = PlannedVendorRecord(
            eventID: eventID,
            vendorID: vendorID,
            category: category.rawValue,
            status: PlannedVendorStatus.planned.rawValue,
            availabilityCheckedAt: .now
        )
        plannedVendors.append(record)
        return record
    }

    func removePlannedVendor(eventID: UUID, vendorID: UUID) async throws {
        plannedVendors.removeAll { $0.eventID == eventID && $0.vendorID == vendorID }
    }

    func updateStatus(eventID: UUID, vendorID: UUID, status: PlannedVendorStatus) async throws {
        guard let index = plannedVendors.firstIndex(where: { $0.eventID == eventID && $0.vendorID == vendorID }) else { return }
        let existing = plannedVendors[index]
        plannedVendors[index] = PlannedVendorRecord(
            id: existing.id,
            eventID: eventID,
            vendorID: vendorID,
            category: existing.category,
            status: status.rawValue,
            availabilityCheckedAt: existing.availabilityCheckedAt
        )
    }

    func batchUpdateStatus(eventID: UUID, vendorIDs: [UUID], status: PlannedVendorStatus) async throws {
        for vendorID in vendorIDs {
            try await updateStatus(eventID: eventID, vendorID: vendorID, status: status)
        }
    }
}

actor TestMessagingService: MessagingServiceProtocol {
    var messages: [UUID: [MessageRecord]] = [:]
    var readConversations: Set<UUID> = []

    func fetchMessages(conversationID: UUID, before cursor: Date?, limit: Int) async throws -> [MessageRecord] {
        let allMessages = messages[conversationID] ?? []
        let filtered: [MessageRecord]
        if let cursor {
            filtered = allMessages.filter { $0.createdAt < cursor }
        } else {
            filtered = allMessages
        }
        return Array(filtered.suffix(limit))
    }

    func sendMessage(conversationID: UUID, body: String, kind: String, senderRole: String, clientID: UUID) async throws -> MessageRecord {
        let record = MessageRecord(
            id: UUID(),
            conversationID: conversationID,
            senderRole: senderRole,
            body: body,
            kind: kind,
            createdAt: .now,
            status: "sent",
            clientID: clientID
        )
        messages[conversationID, default: []].append(record)
        return record
    }

    func markMessagesRead(conversationID: UUID, role: String) async throws {
        readConversations.insert(conversationID)
    }

    func uploadAttachment(data: Data, fileName: String, mimeType: String, userID: UUID) async throws -> String {
        return "\(userID.uuidString)/\(UUID().uuidString)_\(fileName)"
    }

    func createAttachmentRecord(messageID: UUID, storagePath: String, fileName: String, mimeType: String, fileSizeBytes: Int64, width: Int?, height: Int?) async throws -> MessageAttachmentRecord {
        MessageAttachmentRecord(
            id: UUID(),
            messageID: messageID,
            storagePath: storagePath,
            fileName: fileName,
            mimeType: mimeType,
            fileSizeBytes: fileSizeBytes,
            width: width,
            height: height,
            thumbnailPath: nil,
            createdAt: .now
        )
    }

    func fetchAttachments(messageIDs: [UUID]) async throws -> [MessageAttachmentRecord] {
        []
    }

    func signedURL(for storagePath: String) async throws -> URL {
        URL(string: "https://example.com/\(storagePath)")!
    }

    func markMessageDelivered(messageID: UUID) async throws {}

    func fetchMessagesSinceSequence(conversationID: UUID, afterSequence: Int, limit: Int) async throws -> [MessageRecord] {
        let allMessages = messages[conversationID] ?? []
        return allMessages.filter { ($0.sequenceNumber ?? 0) > afterSequence }.prefix(limit).map { $0 }
    }

    func fetchMessagesSince(conversationID: UUID, after: Date, limit: Int) async throws -> [MessageRecord] {
        let allMessages = messages[conversationID] ?? []
        return allMessages.filter { $0.createdAt > after }.prefix(limit).map { $0 }
    }

    func registerDeviceToken(_ token: String, userID: UUID) async throws {}
    func removeDeviceToken(_ token: String, userID: UUID) async throws {}

    func sendMessageWithAttachment(conversationID: UUID, body: String, kind: String, clientID: UUID, storagePath: String, fileName: String, mimeType: String, fileSizeBytes: Int64, width: Int?, height: Int?) async throws -> MessageRecord {
        MessageRecord(
            id: UUID(),
            conversationID: conversationID,
            senderRole: "host",
            body: body,
            kind: kind,
            createdAt: .now,
            clientID: clientID
        )
    }
}

final class MockAnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    private(set) var trackedEvents: [AnalyticsEvent] = []
    private(set) var flushCount = 0
    var insightsToReturn: VendorInsightsRecord?
    var insightsError: Error?

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func flush() async {
        flushCount += 1
    }

    func fetchInsights(period: InsightsPeriod) async throws -> VendorInsightsRecord {
        if let error = insightsError { throw error }
        if let insights = insightsToReturn { return insights }
        throw APIError.notConfigured("No fixture data set")
    }
}
