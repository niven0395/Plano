import SwiftUI

struct VendorDiscoverySheet: View {
    let category: VendorCategory
    let event: PartyEvent
    let planner: HostPlanningStore
    let inboxStore: InboxStore
    let availabilityService: any VendorAvailabilityServiceProtocol
    let onSelectVendor: ((VendorProfile) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @Environment(SessionStore.self) private var session
    @Environment(HostIdentityPromptStore.self) private var hostIdentityPromptStore
    @State private var query = ""
    @State private var loadingState: LoadingState = .idle
    @State private var results: [VendorProfile] = []

    init(
        category: VendorCategory,
        event: PartyEvent,
        planner: HostPlanningStore,
        inboxStore: InboxStore,
        availabilityService: any VendorAvailabilityServiceProtocol,
        onSelectVendor: ((VendorProfile) -> Void)? = nil
    ) {
        self.category = category
        self.event = event
        self.planner = planner
        self.inboxStore = inboxStore
        self.availabilityService = availabilityService
        self.onSelectVendor = onSelectVendor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppSurface(style: .highlighted) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Find a \(category.singularTitle.lowercased())")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("\(event.city) • \(event.formattedDate)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }

                    TextField("Search \(category.title.lowercased())", text: $query)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
                        .onSubmit {
                            Task { await loadResults() }
                        }

                    if loadingState.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                    } else if let message = loadingState.errorMessage {
                        EmptyStateCard(
                            symbolName: "wifi.exclamationmark",
                            title: "Discovery unavailable",
                            message: message
                        )
                    } else if results.isEmpty {
                        EmptyStateCard(
                            symbolName: category.symbolName,
                            title: "No \(category.title.lowercased()) available",
                            message: "Try a broader query or add this category later."
                        )
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(results) { vendor in
                                AppSurface {
                                    VStack(alignment: .leading, spacing: 16) {
                                        VendorDiscoveryResultContent(vendor: vendor)

                                        HStack(spacing: 12) {
                                            NavigationLink {
                                                VendorProfileView(
                                                    store: VendorProfileStore(
                                                        vendorID: vendor.id,
                                                        vendorProfileService: environment.services.vendorProfileService,
                                                        analyticsService: environment.services.analyticsService,
                                                        availabilityService: availabilityService,
                                                        sessionStore: session
                                                    )
                                                )
                                            } label: {
                                                Text(onSelectVendor == nil ? "Open vendor" : "View details")
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(SecondaryActionButtonStyle())

                                            if let onSelectVendor {
                                                Button("Add to event") {
                                                    onSelectVendor(vendor)
                                                    dismiss()
                                                }
                                                .buttonStyle(PrimaryActionButtonStyle())
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(AppTheme.screenPadding)
                .padding(.bottom, 32)
            }
            .background(AppBackdrop())
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadResults()
            }
        }
    }

    private func loadResults() async {
        loadingState = .loading

        do {
            let availableVendorIDs = try await availabilityService.vendorsAvailable(
                on: event.date,
                category: category,
                city: nil
            )
            let vendors = try await planner.searchVendors(
                matching: VendorSearchRequest(
                    text: query,
                    category: category,
                    city: nil,
                    eventDate: event.date,
                    limit: 24
                )
            )

            results = vendors.filter { availableVendorIDs.contains($0.id) }
            loadingState = .loaded
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }
}

private struct VendorDiscoveryResultContent: View {
    let vendor: VendorProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(vendor.businessName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("\(vendor.displayCategoryTitle) • \(vendor.city)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Spacer()

                StatusBadge(title: "Available", tone: .sage)
            }

            Text(vendor.styleSummary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                DiscoveryRoutePill(
                    title: vendor.hostBookingLabel,
                    symbolName: vendor.bookingMode.symbolName,
                    tone: .blue
                )

                DiscoveryRoutePill(
                    title: vendor.hostPaymentLabel,
                    symbolName: vendor.paymentMode.symbolName,
                    tone: vendor.paymentMode == .platform ? .sage : .sand
                )
            }

            HStack {
                Text(vendor.planningPriceLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Spacer()

                Label(vendor.responseTime, systemImage: "clock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
            }
        }
    }
}

private struct DiscoveryRoutePill: View {
    let title: String
    let symbolName: String
    let tone: AccentTone

    var body: some View {
        Label(title, systemImage: symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.toneColor(tone))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.toneBackground(tone), in: Capsule())
    }
}
