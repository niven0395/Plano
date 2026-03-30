import SwiftUI

struct VendorProfileLoadedView: View {
    let vendor: VendorProfile
    @Bindable var store: VendorProfileStore

    @Environment(HostPlanningStore.self) private var planner
    @Environment(InboxStore.self) private var inboxStore
    @Environment(AppRouter.self) private var router
    @Environment(HostIdentityPromptStore.self) private var hostIdentityPromptStore
    @Environment(AuthStore.self) private var authStore
    @Environment(AppEnvironment.self) private var environment

    @State private var bookingStore: VendorBookingRequestStore?
    @State private var pendingBookingDate: Date?

    private var isSaved: Bool {
        store.isSaved(planner: planner)
    }

    private var resolvedEventForBookingCheck: PartyEvent? {
        if let bookingStore, bookingStore.selectedBookingDate != nil {
            return bookingStore.linkedEvent
        }
        return planner.events.isEmpty ? nil : planner.selectedEvent
    }

    private var existingConversationID: UUID? {
        guard let event = resolvedEventForBookingCheck else { return nil }
        return inboxStore.existingConversationID(
            vendorID: vendor.id,
            eventID: event.id
        )
    }

    private var existingConversationStage: BookingStage? {
        guard let conversationID = existingConversationID else { return nil }
        return inboxStore.conversation(id: conversationID, for: .host)?.stage
    }

    private var hasBlockingBooking: Bool {
        guard let stage = existingConversationStage else { return false }
        let blockingStages: Set<BookingStage> = [.requested, .accepted, .paymentRequested, .paid]
        return blockingStages.contains(stage)
    }

    private var hasSelectedEvent: Bool {
        !planner.events.isEmpty
    }

    private var primaryActionTitle: String {
        if store.isOwnVendorProfile {
            return "Your listing"
        }
        if hasBlockingBooking {
            return "View booking"
        }
        if existingConversationID != nil {
            return "Open chat"
        }
        if !hasSelectedEvent {
            return "Start inquiry"
        }
        return vendor.primaryCTA ?? "Message vendor"
    }

    private var shortlistActionTitle: String {
        "Shortlist"
    }

    private var shortlistSymbolName: String {
        isSaved ? "heart.fill" : "heart"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VendorProfileHeroCard(vendor: vendor)
                    .staggeredAppear(index: 0)

                if store.shouldShowStats {
                    VendorProfileStatsCard(vendor: vendor)
                        .staggeredAppear(index: 1)
                }

                if store.shouldShowAbout {
                    SectionHeader(title: "About")
                    VendorProfileAboutCard(vendor: vendor)
                        .staggeredAppear(index: 2)
                }

                if store.shouldShowCategoryDetails, let details = vendor.categoryDetails {
                    SectionHeader(title: details.sectionTitle)
                    CategoryDetailsSection(details: details)
                        .staggeredAppear(index: 3)
                }

                if store.shouldShowServices {
                    SectionHeader(title: "Services")
                    VendorProfileServicesCard(services: vendor.services)
                        .staggeredAppear(index: 4)
                }

                if store.shouldShowGallery {
                    SectionHeader(title: "Gallery")
                    VendorProfileGalleryCard(
                        galleryImages: vendor.galleryImages,
                        businessName: vendor.businessName
                    )
                    .staggeredAppear(index: 5)
                }

                if store.canInitiateConversation {
                    if store.sessionStore.isAnonymous {
                        VendorProfileAuthPrompt(authStore: authStore)
                    } else if hasBlockingBooking, let stage = existingConversationStage {
                        AppSurface {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.toneColor(stage.tone))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Booking \(stage.title.lowercased())")
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.Palette.textPrimary)

                                    Text("Open the conversation to manage it.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Palette.textSecondary)
                                }

                                Spacer()

                                StatusBadge(title: stage.title, tone: stage.tone)
                            }
                        }
                    } else if vendor.isInquiryOnly {
                        VendorProfileInquiryCard(
                            vendorName: vendor.businessName,
                            businessEmail: vendor.businessEmail,
                            onSendInquiry: {
                                store.openConversation(
                                    planner: planner,
                                    inboxStore: inboxStore,
                                    router: router,
                                    hostIdentityPromptStore: hostIdentityPromptStore
                                )
                            }
                        )
                    } else if vendor.usesEventTimeRange {
                        SectionHeader(title: "Request a booking")

                        if let bookingStore {
                            EventTimeRangeBookingSection(
                                vendor: vendor,
                                store: bookingStore
                            )
                        } else {
                            EventTimeRangeBookingSection(
                                vendor: vendor,
                                store: initAndReturnBookingStore()
                            )
                        }
                    } else if let bookingStore {
                        VendorProfileBookingSection(
                            vendor: vendor,
                            store: bookingStore,
                            availabilityRecords: store.availabilityRecords
                        )
                    } else {
                        SectionHeader(title: "Pick a date")

                        AppSurface {
                            VStack(alignment: .leading, spacing: 16) {
                                HostBookingCalendar(
                                    vendorProfile: vendor,
                                    availabilityRecords: store.availabilityRecords,
                                    selectedDate: Binding(
                                        get: { pendingBookingDate },
                                        set: { date in
                                            pendingBookingDate = date
                                            if date != nil {
                                                initBookingStore()
                                                bookingStore?.selectedBookingDate = date
                                                bookingStore?.resolveLinkedEvent(for: date)
                                            }
                                        }
                                    )
                                )

                                Button("Request Booking") { }
                                    .buttonStyle(PrimaryActionButtonStyle())
                                    .disabled(true)
                            }
                        }
                    }
                }

                if !vendor.packages.isEmpty {
                    SectionHeader(title: "Packages")
                    LazyVStack(spacing: 16) {
                        ForEach(vendor.packages) { package in
                            VendorProfilePackageCard(package: package)
                        }
                    }
                }

                if !vendor.addOns.isEmpty {
                    SectionHeader(title: "Add-ons")
                    VendorProfileAddOnsCard(addOns: vendor.addOns)
                }

                if !vendor.pricingImagePaths.isEmpty {
                    SectionHeader(title: "Price sheet")
                    VendorProfilePricingImagesCard(imagePaths: vendor.pricingImagePaths)
                }

                if store.shouldShowReviews {
                    SectionHeader(title: "Reviews")
                    LazyVStack(spacing: 16) {
                        ForEach(vendor.reviewHighlights) { review in
                            VendorProfileReviewCard(review: review)
                        }
                    }
                }

                if store.shouldShowPolicies {
                    SectionHeader(title: "Policies")
                    VendorProfilePoliciesCard(policies: vendor.policies)
                }

                if !store.isOwnVendorProfile, !vendor.isInquiryOnly, store.canInitiateConversation || vendor.businessEmail != nil {
                    SectionHeader(title: "Contact")
                    VendorProfileContactCard(
                        vendor: vendor,
                        primaryActionTitle: store.sessionStore.isAnonymous ? "Create an account" : primaryActionTitle,
                        canInitiateConversation: store.canInitiateConversation,
                        onMessageAction: {
                            if store.sessionStore.isAnonymous {
                                authStore.presentCreateAccount()
                            } else {
                                store.openConversation(
                                    planner: planner,
                                    inboxStore: inboxStore,
                                    router: router,
                                    hostIdentityPromptStore: hostIdentityPromptStore
                                )
                            }
                        }
                    )
                }

                if store.shouldShowSocial {
                    SectionHeader(title: "Social")
                    VendorProfileSocialCard(socialLinks: vendor.socialLinks)
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle(vendor.businessName)
        .navigationBarTitleDisplayMode(.inline)
        .transition(.opacity.combined(with: .blurReplace))
        .hapticFeedback(.impact(weight: .medium), trigger: isSaved)
        .sheet(isPresented: Binding(
            get: { bookingStore?.isPresentingBookingSheet ?? false },
            set: { bookingStore?.isPresentingBookingSheet = $0 }
        )) {
            if let bookingStore, let date = bookingStore.selectedBookingDate {
                BookingRequestSheet(
                    vendorName: vendor.businessName,
                    selectedDate: date,
                    selectedTimeslot: bookingStore.selectedTimeslot,
                    requestedStartTime: bookingStore.requestedStartTime,
                    requestedEndTime: bookingStore.requestedEndTime,
                    linkedEvent: bookingStore.linkedEvent,
                    availableEvents: planner.events,
                    onEventChanged: { bookingStore.setLinkedEvent($0) },
                    note: Bindable(bookingStore).bookingNote,
                    isSubmitting: bookingStore.isSubmittingBooking,
                    onSubmit: {
                        Task {
                            if let refreshed = await bookingStore.submitBookingRequest(
                                date: date,
                                note: bookingStore.bookingNote,
                                vendor: vendor
                            ) {
                                store.availabilityRecords = refreshed
                            }
                        }
                    },
                    onCancel: { bookingStore.isPresentingBookingSheet = false }
                )
            }
        }
        .alert(
            "Booking Failed",
            isPresented: Binding(
                get: { bookingStore?.bookingError != nil },
                set: { if !$0 { bookingStore?.bookingError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(bookingStore?.bookingError ?? "Something went wrong. Please try again.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(
                    shortlistActionTitle,
                    systemImage: shortlistSymbolName,
                    action: { store.toggleSaved(planner: planner) }
                )
                .labelStyle(.iconOnly)
                .symbolEffect(.bounce, value: isSaved)
                .foregroundStyle(isSaved ? AppTheme.toneColor(.coral) : AppTheme.Palette.textPrimary)
                .accessibilityLabel(isSaved ? "Remove from shortlist" : "Save to shortlist")
            }
        }
    }

    private func initBookingStore() {
        guard bookingStore == nil else { return }
        bookingStore = VendorBookingRequestStore(
            vendorID: vendor.id,
            bookingService: environment.services.bookingService,
            availabilityService: environment.services.availabilityService,
            inboxStore: inboxStore,
            planner: planner,
            router: router
        )
        Task {
            await bookingStore?.loadTimeslotBookings(vendor: vendor)
        }
    }

    @discardableResult
    private func initAndReturnBookingStore() -> VendorBookingRequestStore {
        if let bookingStore { return bookingStore }
        let newStore = VendorBookingRequestStore(
            vendorID: vendor.id,
            bookingService: environment.services.bookingService,
            availabilityService: environment.services.availabilityService,
            inboxStore: inboxStore,
            planner: planner,
            router: router
        )
        newStore.schedulingMode = vendor.schedulingMode
        newStore.initializeEventTimeRangeDefaults()
        bookingStore = newStore
        return newStore
    }
}

private struct VendorProfileBookingSection: View {
    let vendor: VendorProfile
    @Bindable var store: VendorBookingRequestStore
    let availabilityRecords: [VendorAvailabilityRecord]

    var body: some View {
        SectionHeader(title: "Pick a date")

        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                HostBookingCalendar(
                    vendorProfile: vendor,
                    availabilityRecords: availabilityRecords,
                    selectedDate: $store.selectedBookingDate
                )

                if store.vendorHasTimeslots, store.selectedBookingDate != nil {
                    TimeslotPickerView(
                        slots: store.availableTimeslots,
                        selectedSlot: $store.selectedTimeslot
                    )
                }

                Button("Request Booking") {
                    store.isPresentingBookingSheet = true
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!store.canSubmitBooking)
            }
        }
        .onChange(of: store.selectedBookingDate) { _, newDate in
            store.selectedTimeslot = nil
            store.updateTimeslotsForSelectedDate(vendor: vendor)
            store.resolveLinkedEvent(for: newDate)
        }
    }
}

private struct VendorProfileAuthPrompt: View {
    let authStore: AuthStore

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Want to book this vendor?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Create an account to request bookings and message vendors.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Button("Create an account") {
                    authStore.presentCreateAccount()
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button("Already have an account? Sign in") {
                    authStore.presentEmailAuth()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Palette.accent)
                .buttonStyle(.plain)
            }
        }
    }
}

private struct VendorProfileContactCard: View {
    let vendor: VendorProfile
    let primaryActionTitle: String
    let canInitiateConversation: Bool
    let onMessageAction: () -> Void

    @Environment(\.openURL) private var openURL

    private var hasEmail: Bool {
        guard let email = vendor.businessEmail else { return false }
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        AppSurface {
            VStack(spacing: 12) {
                if canInitiateConversation {
                    Button(action: onMessageAction) {
                        Label(primaryActionTitle, systemImage: "bubble.left.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }

                if hasEmail, let email = vendor.businessEmail,
                   let url = URL(string: "mailto:\(email)") {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Email", systemImage: "envelope")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}

private struct VendorProfileInquiryCard: View {
    let vendorName: String
    let businessEmail: String?
    let onSendInquiry: () -> Void

    @Environment(\.openURL) private var openURL

    private var hasEmail: Bool {
        guard let email = businessEmail else { return false }
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SectionHeader(title: "Get in touch")

        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inquiry only")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("\(vendorName) manages bookings directly. Send a message to get started.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                } icon: {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Palette.accent)
                }

                Button(action: onSendInquiry) {
                    Label("Send inquiry", systemImage: "bubble.left.fill")
                }
                .buttonStyle(PrimaryActionButtonStyle())

                if hasEmail, let email = businessEmail,
                   let url = URL(string: "mailto:\(email)") {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Email", systemImage: "envelope")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}
