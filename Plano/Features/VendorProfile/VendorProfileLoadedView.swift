import SwiftUI

struct VendorProfileLoadedView: View {
    let vendor: VendorProfile
    @Bindable var store: VendorProfileStore

    @Environment(HostPlanningStore.self) private var planner
    @Environment(InboxStore.self) private var inboxStore
    @Environment(AppRouter.self) private var router
    @Environment(HostIdentityPromptStore.self) private var hostIdentityPromptStore
    @Environment(AppEnvironment.self) private var environment

    @State private var bookingStore: VendorBookingRequestStore?
    @State private var pendingBookingDate: Date?

    private var isSaved: Bool {
        store.isSaved(planner: planner)
    }

    private var existingConversationID: UUID? {
        inboxStore.existingConversationID(
            vendorID: vendor.id,
            eventID: planner.selectedEvent.id
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
                    if hasBlockingBooking, let stage = existingConversationStage {
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

                if store.shouldShowSocial {
                    SectionHeader(title: "Social & Contact")
                    VendorProfileSocialCard(socialLinks: vendor.socialLinks)
                }

                VendorProfileCTACardView(
                    vendor: vendor,
                    hasBlockingBooking: hasBlockingBooking,
                    existingConversationStage: existingConversationStage,
                    hasSelectedEvent: hasSelectedEvent,
                    primaryActionTitle: primaryActionTitle,
                    shortlistActionTitle: shortlistActionTitle,
                    canInitiateConversation: store.canInitiateConversation,
                    isOwnVendorProfile: store.isOwnVendorProfile,
                    isSaved: isSaved,
                    onPrimaryAction: {
                        store.openConversation(
                            planner: planner,
                            inboxStore: inboxStore,
                            router: router,
                            hostIdentityPromptStore: hostIdentityPromptStore
                        )
                    },
                    onToggleSaved: { store.toggleSaved(planner: planner) }
                )
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
        .onChange(of: store.selectedBookingDate) { _, _ in
            store.selectedTimeslot = nil
            store.updateTimeslotsForSelectedDate(vendor: vendor)
        }
    }
}

private struct VendorProfileCTACardView: View {
    let vendor: VendorProfile
    let hasBlockingBooking: Bool
    let existingConversationStage: BookingStage?
    let hasSelectedEvent: Bool
    let primaryActionTitle: String
    let shortlistActionTitle: String
    let canInitiateConversation: Bool
    let isOwnVendorProfile: Bool
    let isSaved: Bool
    let onPrimaryAction: () -> Void
    let onToggleSaved: () -> Void

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Next steps")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                if hasBlockingBooking, let stage = existingConversationStage {
                    Text("Your booking with \(vendor.businessName) is \(stage.title.lowercased()). Open the conversation to manage it.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                } else if hasSelectedEvent {
                    Text("Interested in \(vendor.businessName)? Start a conversation or request a booking.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                } else {
                    Text("Send a message to learn more about availability and pricing.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Text(vendor.availabilitySummary.eventDateSupportLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(
                        vendor.availabilitySummary.supportsSelectedEventDate
                            ? AppTheme.toneColor(.sage)
                            : AppTheme.toneColor(.coral)
                    )

                HStack(spacing: 10) {
                    routingBadge(
                        title: vendor.hostBookingLabel,
                        symbolName: vendor.bookingMode.symbolName,
                        tone: .blue
                    )

                    routingBadge(
                        title: vendor.hostPaymentLabel,
                        symbolName: vendor.paymentMode.symbolName,
                        tone: vendor.paymentMode == .platform ? .sage : .sand
                    )
                }

                if let days = vendor.cancellationDeadlineDays {
                    Label("Free cancellation up to \(days) days before your event", systemImage: "clock.badge.checkmark")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                if canInitiateConversation {
                    HStack(spacing: 12) {
                        Button(primaryActionTitle, action: onPrimaryAction)
                            .buttonStyle(PrimaryActionButtonStyle())

                        Button(shortlistActionTitle, action: onToggleSaved)
                            .buttonStyle(SecondaryActionButtonStyle())
                    }
                } else if isOwnVendorProfile {
                    HStack(spacing: 12) {
                        Button(primaryActionTitle) {}
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(true)

                        Button(shortlistActionTitle, action: onToggleSaved)
                            .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }
        }
    }

    private func routingBadge(title: String, symbolName: String, tone: AccentTone) -> some View {
        Label(title, systemImage: symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.toneColor(tone))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.toneBackground(tone), in: Capsule())
    }
}
