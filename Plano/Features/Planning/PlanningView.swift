import SwiftUI

struct PlanningView: View {
    @Environment(AppRouter.self) private var router
    @Environment(HostPlanningStore.self) private var planner
    @Environment(InboxStore.self) private var inboxStore
    @Environment(SessionStore.self) private var session

    // Active booking conversations: non-terminal, non-active, not archived, for current host
    private var activeBookings: [ConversationThread] {
        inboxStore.conversations
            .filter { !$0.stage.isTerminal && $0.stage != .active && !inboxStore.isArchived($0.id, for: .host) }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    // Saved vendors resolved from cache
    private var savedVendors: [VendorProfile] {
        planner.savedVendorIDs.compactMap { planner.vendor(id: $0) }
            .sorted { $0.businessName < $1.businessName }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Planning")

                if activeBookings.isEmpty && savedVendors.isEmpty {
                    emptyState
                } else {
                    if !activeBookings.isEmpty {
                        bookingsSection
                    }

                    if !savedVendors.isEmpty {
                        savedSection
                    }
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Your Vendors

    @ViewBuilder
    private var bookingsSection: some View {
        PlanningSectionHeader(
            title: "Your vendors",
            count: activeBookings.count,
            subtitle: "\(activeBookings.count) active booking\(activeBookings.count == 1 ? "" : "s")"
        )

        LazyVStack(spacing: 12) {
            ForEach(activeBookings) { thread in
                NavigationLink(value: DiscoveryRoute.bookingDetail(thread.id)) {
                    ActiveBookingCard(
                        vendorName: thread.vendorName,
                        category: thread.vendorCategory,
                        stage: thread.stage,
                        eventDate: thread.bookingEventDate
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Saved

    @ViewBuilder
    private var savedSection: some View {
        PlanningSectionHeader(
            title: "Saved",
            count: savedVendors.count,
            subtitle: "\(savedVendors.count) shortlisted vendor\(savedVendors.count == 1 ? "" : "s")"
        )

        LazyVStack(spacing: 10) {
            ForEach(savedVendors) { vendor in
                NavigationLink(value: DiscoveryRoute.vendorProfile(vendor.id)) {
                    SavedVendorRow(
                        vendorName: vendor.businessName,
                        category: vendor.category,
                        rating: vendor.ratingValue > 0 ? vendor.ratingText : nil,
                        reviewCount: vendor.reviewCount
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your planning hub")
                    .font(.system(size: 28, weight: .regular))
                    .tracking(-0.8)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Vendors you book or save will appear here so you can track everything in one place.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }
}

// MARK: - Section Header with count pill

private struct PlanningSectionHeader: View {
    let title: String
    let count: Int
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 32, weight: .regular))
                    .tracking(-1.1)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                if count > 0 {
                    Text("\(count)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(AppTheme.Palette.chipFill, in: Capsule())
                }
            }

            Text(subtitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
    }
}

// MARK: - Active Booking Card (full card treatment)

private struct ActiveBookingCard: View {
    let vendorName: String
    let category: VendorCategory
    let stage: BookingStage
    let eventDate: Date?

    private var isUrgent: Bool {
        // Urgent stages = those requiring imminent action
        stage == .paymentRequested || stage == .requested || stage == .cancellationRequested
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isUrgent ? AppTheme.toneColor(stage.tone) : Color.clear)
                .frame(width: 3)
                .accessibilityHidden(true)

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.toneBackground(category.accentTone))
                            Image(systemName: category.symbolName)
                                .font(.headline)
                                .foregroundStyle(AppTheme.toneColor(category.accentTone))
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(vendorName)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                                .lineLimit(1)

                            Text(category.singularTitle)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }

                        Spacer(minLength: 8)

                        StatusBadge(title: stage.title, tone: stage.tone)
                    }

                    if let eventDate {
                        Label {
                            Text(eventDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .font(.footnote.weight(.semibold))
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.footnote)
                        }
                        .foregroundStyle(AppTheme.Palette.subdued)
                    }
                }
            }
        }
    }
}

// MARK: - Saved Vendor Row (compact reference)

private struct SavedVendorRow: View {
    let vendorName: String
    let category: VendorCategory
    let rating: String?
    let reviewCount: Int

    var body: some View {
        AppSurface(compact: true) {
            HStack(spacing: 12) {
                Image(systemName: category.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.toneColor(category.accentTone))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.toneBackground(category.accentTone), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(vendorName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                        .lineLimit(1)

                    Text(category.singularTitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Spacer(minLength: 8)

                if let rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.toneColor(.gold))
                        Text(rating)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                        if reviewCount > 0 {
                            Text("(\(reviewCount))")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(rating) stars from \(reviewCount) reviews")
                }
            }
        }
    }
}
