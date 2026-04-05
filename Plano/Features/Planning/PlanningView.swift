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
        SectionHeader(
            title: "Your vendors",
            subtitle: "\(activeBookings.count) active booking\(activeBookings.count == 1 ? "" : "s")"
        )

        LazyVStack(spacing: 12) {
            ForEach(activeBookings) { thread in
                NavigationLink(value: DiscoveryRoute.bookingDetail(thread.id)) {
                    PlanningVendorRow(
                        vendorName: thread.vendorName,
                        category: thread.vendorCategory,
                        stage: thread.stage
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Saved

    @ViewBuilder
    private var savedSection: some View {
        SectionHeader(
            title: "Saved",
            subtitle: "\(savedVendors.count) shortlisted vendor\(savedVendors.count == 1 ? "" : "s")"
        )

        LazyVStack(spacing: 12) {
            ForEach(savedVendors) { vendor in
                NavigationLink(value: DiscoveryRoute.vendorProfile(vendor.id)) {
                    PlanningVendorRow(
                        vendorName: vendor.businessName,
                        category: vendor.category,
                        stage: nil,
                        ratingLabel: vendor.ratingValue > 0 ? String(format: "%.1f", vendor.ratingValue) : nil
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

// MARK: - Planning Vendor Row

private struct PlanningVendorRow: View {
    let vendorName: String
    let category: VendorCategory
    let stage: BookingStage?
    var ratingLabel: String? = nil

    var body: some View {
        AppSurface {
            HStack(spacing: 12) {
                Image(systemName: category.symbolName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.toneColor(category.accentTone))

                VStack(alignment: .leading, spacing: 4) {
                    Text(vendorName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(category.singularTitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Spacer()

                if let stage {
                    StatusBadge(title: stage.title, tone: stage.tone)
                } else if let ratingLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.toneColor(.gold))
                        Text(ratingLabel)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
            }
        }
    }
}
