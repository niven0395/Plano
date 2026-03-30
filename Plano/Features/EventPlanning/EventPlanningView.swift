import SwiftUI

struct EventPlanningView: View {
    let store: EventPlanningStore

    @Environment(AppRouter.self) private var router
    @State private var presentedCategory: VendorCategory?
    @State private var selectedBookingVendor: RequestsStore.VendorItem?

    var body: some View {
        Group {
            if let event = store.event {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SectionHeader(title: "Event Plan")

                        header(for: event)

                        SectionHeader(
                            title: "Vendor plan",
                            subtitle: "Build the event one category at a time."
                        )

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14),
                            ],
                            spacing: 14
                        ) {
                            ForEach(store.categorySlots) { slot in
                                VendorCategorySlotView(slot: slot) {
                                    if let vendor = slot.vendor,
                                       let conversationID = slot.conversationID,
                                       let stage = slot.bookingStage {
                                        selectedBookingVendor = RequestsStore.VendorItem(
                                            id: conversationID,
                                            vendorID: vendor.id,
                                            vendorName: vendor.businessName,
                                            category: slot.category,
                                            stage: stage,
                                            priceLabel: vendor.visibleStartingPriceLabel ?? "Pricing on request",
                                            eventDateLabel: "",
                                            conversationID: conversationID
                                        )
                                    } else {
                                        presentedCategory = slot.category
                                    }
                                }
                            }
                        }

                        Menu {
                            ForEach(store.availableAdditionalCategories) { category in
                                Button(category.title) {
                                    store.addCategory(category)
                                }
                            }
                        } label: {
                            Label("Add category", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                    .padding(AppTheme.screenPadding)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(AppBackdrop())
                .toolbar(.hidden, for: .navigationBar)
                .sheet(item: $presentedCategory) { category in
                    VendorDiscoverySheet(
                        category: category,
                        event: event,
                        planner: store.planner,
                        inboxStore: store.inboxStore,
                        availabilityService: store.availabilityService
                    )
                }
                .sheet(item: $selectedBookingVendor) { vendor in
                    VendorBookingDetailSheet(
                        vendor: vendor,
                        onOpenChat: { router.openConversation($0) },
                        onViewProfile: { router.openVendorProfile($0) },
                        onConfirmPayment: { await store.inboxStore.confirmPayment(in: $0) }
                    )
                }
                .task {
                    await store.loadIfNeeded()
                }
            } else {
                EmptyStateCard(
                    symbolName: "calendar.badge.exclamationmark",
                    title: "Event unavailable",
                    message: "This event could not be loaded."
                )
                .padding(AppTheme.screenPadding)
                .background(AppBackdrop())
            }
        }
    }

    private func header(for event: PartyEvent) -> some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.system(size: 30, weight: .regular))
                            .tracking(-0.8)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(event.type.title)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }

                    Spacer()

                    StatusBadge(title: event.stage.title, tone: event.stage.tone)
                }

                HStack(spacing: 12) {
                    Label(event.formattedDateWithTime, systemImage: "calendar")
                    Label(event.venue, systemImage: "mappin.and.ellipse")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

                Text("\(event.guestCountLabel) · \(event.venueSetting.title)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                HStack(spacing: 12) {
                    Button("Open workspace") {
                        router.openHostEventWorkspace(event.id)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button("Browse all") {
                        router.selectedTab = .home
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}
