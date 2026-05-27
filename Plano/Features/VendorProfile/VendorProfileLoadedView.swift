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
    @State private var isPresentingShareSheet = false

    private var isSaved: Bool {
        store.isSaved(planner: planner)
    }

    private var existingConversationID: UUID? {
        inboxStore.existingConversationID(vendorID: vendor.id)
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
        return vendor.primaryCTA ?? "Message vendor"
    }

    private var shortlistActionTitle: String {
        "Shortlist"
    }

    private var shortlistSymbolName: String {
        isSaved ? "heart.fill" : "heart"
    }

    private var floatingActionSymbol: String {
        if hasBlockingBooking { return "calendar.badge.clock" }
        return "bubble.left.fill"
    }

    /// Show the pinned bottom CTA whenever the user has a booking-related action available.
    /// Inquiry-only vendors keep their in-flow card; anonymous users get the auth prompt instead.
    private var shouldShowFloatingActionBar: Bool {
        guard !store.sessionStore.isAnonymous else { return false }
        guard !store.isOwnVendorProfile else { return false }
        guard !vendor.isInquiryOnly else { return false }
        return store.canInitiateConversation
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // MARK: Act 1 — Identity (hero with absorbed stats + signal row)
                VendorProfileHeroCard(vendor: vendor)
                    .staggeredAppear(index: 0)

                // MARK: Act 2 — Work (gallery first, then copy)
                if store.shouldShowGallery {
                    VendorProfileGalleryCard(
                        galleryImages: vendor.galleryImages,
                        businessName: vendor.businessName
                    )
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

                // MARK: Act 3 — Offering (packages, add-ons, pricing)
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

                // MARK: Act 4 — Logistics (booking, policies, reviews, social)
                if store.canInitiateConversation, !store.sessionStore.isAnonymous {
                    if hasBlockingBooking, let stage = existingConversationStage, let conversationID = existingConversationID {
                        NavigationLink(value: DiscoveryRoute.bookingDetail(conversationID)) {
                            AppSurface {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.title3)
                                        .foregroundStyle(AppTheme.toneColor(stage.tone))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Booking \(stage.title.lowercased())")
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.Palette.textPrimary)

                                        Text("View booking details and manage it.")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.Palette.textSecondary)
                                    }

                                    Spacer()

                                    StatusBadge(title: stage.title, tone: stage.tone)
                                }
                            }
                        }
                        .buttonStyle(.plain)
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
                        }
                    } else if let bookingStore {
                        VendorProfileBookingSection(
                            vendor: vendor,
                            store: bookingStore,
                            availabilityRecords: store.availabilityRecords
                        )
                    }
                }

                if store.shouldShowPolicies {
                    SectionHeader(title: "The details")
                    VendorProfilePoliciesCard(policies: vendor.policies)
                }

                if store.shouldShowReviews {
                    SectionHeader(title: "Reviews")
                    LazyVStack(spacing: 16) {
                        ForEach(vendor.reviewHighlights) { review in
                            VendorProfileReviewCard(review: review)
                        }
                    }
                }

                if store.shouldShowSocial {
                    SectionHeader(title: "Social")
                    VendorProfileSocialCard(socialLinks: vendor.socialLinks)
                }

                if store.sessionStore.isAnonymous {
                    VendorProfileAuthPrompt(authStore: authStore)
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, shouldShowFloatingActionBar ? 96 : 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .safeAreaInset(edge: .bottom) {
            if shouldShowFloatingActionBar {
                if hasBlockingBooking {
                    VendorProfileFloatingActionBar(
                        priceLabel: nil,
                        actionTitle: primaryActionTitle,
                        systemImage: floatingActionSymbol,
                        bookingDetailRoute: existingConversationID.map { DiscoveryRoute.bookingDetail($0) },
                        onAction: {}
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    VendorProfileComposerDock(
                        vendor: vendor,
                        isSending: bookingStore?.isSubmittingBooking ?? false,
                        onSendMessage: { message in
                            store.submitInitialMessage(
                                message: message,
                                inboxStore: inboxStore,
                                router: router,
                                hostIdentityPromptStore: hostIdentityPromptStore
                            )
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(vendor.businessName)
        .navigationBarTitleDisplayMode(.inline)
        .transition(.opacity.combined(with: .blurReplace))
        .hapticFeedback(.impact(weight: .medium), trigger: isSaved)
        .bookingPresentation(
            bookingStore: bookingStore,
            vendor: vendor,
            onAvailabilityRefresh: { store.availabilityRecords = $0 }
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.isOwnVendorProfile {
                    Button("Share booking link", systemImage: "square.and.arrow.up") {
                        isPresentingShareSheet = true
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .accessibilityLabel("Share booking link")
                    .sheet(isPresented: $isPresentingShareSheet) {
                        VendorShareLinkSheet(vendorID: vendor.id, vendorName: vendor.businessName)
                    }
                } else {
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
        .task(id: vendor.id) {
            guard bookingStore == nil else { return }
            let newStore = VendorBookingRequestStore(
                vendorID: vendor.id,
                bookingService: environment.services.bookingService,
                availabilityService: environment.services.availabilityService,
                inboxStore: inboxStore,
                router: router
            )
            newStore.schedulingMode = vendor.schedulingMode
            newStore.initializeEventTimeRangeDefaults()
            bookingStore = newStore
            await newStore.loadTimeslotBookings(vendor: vendor)
        }
    }
}

private struct VendorProfileBookingPresenter: ViewModifier {
    @Bindable var bookingStore: VendorBookingRequestStore
    let vendor: VendorProfile
    let onAvailabilityRefresh: ([VendorAvailabilityRecord]) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $bookingStore.isPresentingBookingSheet) {
                if let date = bookingStore.selectedBookingDate {
                    BookingRequestSheet(
                        vendorName: vendor.businessName,
                        selectedDate: date,
                        selectedTimeslot: bookingStore.selectedTimeslot,
                        requestedStartTime: bookingStore.requestedStartTime,
                        requestedEndTime: bookingStore.requestedEndTime,
                        note: $bookingStore.bookingNote,
                        showsGuestCount: vendor.collectsGuestCount,
                        guestCountLabel: $bookingStore.guestCountLabel,
                        intakeQuestions: vendor.enabledLeadIntakeQuestions,
                        intakeAnswers: $bookingStore.intakeAnswers,
                        isSubmitting: bookingStore.isSubmittingBooking,
                        bookingSubmittedSuccessfully: bookingStore.bookingSubmittedSuccessfully,
                        hasValidTimeRange: bookingStore.schedulingMode != .eventTimeRange || bookingStore.hasValidRequestedTimeRange,
                        onSubmit: {
                            Task {
                                if let refreshed = await bookingStore.submitBookingRequest(
                                    date: date,
                                    note: bookingStore.bookingNote,
                                    vendor: vendor
                                ) {
                                    onAvailabilityRefresh(refreshed)
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
                    get: { bookingStore.bookingError != nil },
                    set: { if !$0 { bookingStore.bookingError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(bookingStore.bookingError ?? "Something went wrong. Please try again.")
            }
    }
}

private extension View {
    @ViewBuilder
    func bookingPresentation(
        bookingStore: VendorBookingRequestStore?,
        vendor: VendorProfile,
        onAvailabilityRefresh: @escaping ([VendorAvailabilityRecord]) -> Void
    ) -> some View {
        if let bookingStore {
            modifier(VendorProfileBookingPresenter(
                bookingStore: bookingStore,
                vendor: vendor,
                onAvailabilityRefresh: onAvailabilityRefresh
            ))
        } else {
            self
        }
    }
}

private struct VendorProfileBookingSection: View {
    let vendor: VendorProfile
    @Bindable var store: VendorBookingRequestStore
    let availabilityRecords: [VendorAvailabilityRecord]

    private static let summaryDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return df
    }()

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

                if store.canSubmitBooking, let date = store.selectedBookingDate {
                    requestActionCard(date: date)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.snappy, value: store.canSubmitBooking)
        }
        .hapticFeedback(.impact(weight: .light), trigger: store.canSubmitBooking) { old, new in
            !old && new
        }
        .onChange(of: store.selectedBookingDate) { _, _ in
            store.selectedTimeslot = nil
            store.updateTimeslotsForSelectedDate(vendor: vendor)
        }
    }

    @ViewBuilder
    private func requestActionCard(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Palette.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.summaryDateFormatter.string(from: date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    if let slot = store.selectedTimeslot {
                        Text(slot.timeRangeLabel)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

                Spacer()

                Button("Clear") {
                    store.selectedBookingDate = nil
                    store.selectedTimeslot = nil
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)
                .buttonStyle(.plain)
                .accessibilityLabel("Clear selected date")
            }

            Button("Request booking") {
                store.isPresentingBookingSheet = true
            }
            .buttonStyle(PrimaryActionButtonStyle())
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

                Button("Sign in or create an account") {
                    authStore.presentSignIn()
                }
                .buttonStyle(PrimaryActionButtonStyle())
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

// MARK: - Floating Action Bar

private struct VendorProfileFloatingActionBar: View {
    let priceLabel: String?
    let actionTitle: String
    let systemImage: String
    let bookingDetailRoute: DiscoveryRoute?
    let onAction: () -> Void

    var body: some View {
        AppFloatingActionBar {
            if let priceLabel, !priceLabel.isEmpty {
                AppFloatingActionBarPriceBlock(priceLabel: priceLabel)
            }
        } trailing: {
            Group {
                if let bookingDetailRoute {
                    NavigationLink(value: bookingDetailRoute) {
                        Label(actionTitle, systemImage: systemImage)
                    }
                } else {
                    Button(action: onAction) {
                        Label(actionTitle, systemImage: systemImage)
                    }
                }
            }
            .buttonStyle(AppFloatingActionBarButtonStyle())
            .accessibilityLabel(actionTitle)
        }
    }
}
