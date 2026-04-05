import SwiftUI

struct VendorProfileView: View {
    @State private var store: VendorProfileStore

    init(
        vendorID: UUID,
        vendorProfileService: any VendorProfileServiceProtocol,
        analyticsService: any AnalyticsServiceProtocol,
        availabilityService: any VendorAvailabilityServiceProtocol,
        sessionStore: SessionStore
    ) {
        _store = State(initialValue: VendorProfileStore(
            vendorID: vendorID,
            vendorProfileService: vendorProfileService,
            analyticsService: analyticsService,
            availabilityService: availabilityService,
            sessionStore: sessionStore
        ))
    }

    var body: some View {
        Group {
            if let vendor = store.vendor {
                VendorProfileLoadedView(vendor: vendor, store: store)
            } else if store.loadingState.isLoading {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VendorProfileSkeleton()
                    }
                    .padding(AppTheme.screenPadding)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(AppBackdrop())
                .transition(.opacity.combined(with: .blurReplace))
            } else {
                EmptyStateCard(
                    symbolName: "person.crop.square",
                    title: "Vendor unavailable",
                    message: store.loadingState.errorMessage ?? "The selected vendor profile could not be loaded."
                )
                .padding(AppTheme.screenPadding)
                .background(AppBackdrop())
            }
        }
        .animation(.easeOut(duration: 0.3), value: store.vendor != nil)
        .task {
            await store.loadIfNeeded()
        }
    }
}

// MARK: - Hero Card

struct VendorProfileHeroCard: View {
    let vendor: VendorProfile

    private let imageHeight: Double = 260
    private let nameStripHeight: Double = 60
    private let cornerRadius = AppTheme.cardCornerRadius

    var body: some View {
        ZStack(alignment: .bottom) {
            // Image fills the full height (visible area + behind the frosted strip)
            Group {
                if let path = vendor.profileImagePath, !path.isEmpty {
                    PlanoImage(
                        storagePath: path,
                        size: .standard,
                        cornerRadius: 0,
                        contentMode: .fill
                    )
                } else {
                    Rectangle()
                        .fill(AppTheme.toneBackground(vendor.category.accentTone))
                        .overlay {
                            Image(systemName: vendor.category.symbolName)
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.toneColor(vendor.category.accentTone))
                        }
                }
            }
            .frame(height: imageHeight)
            .frame(maxWidth: .infinity)
            .clipped()

            // Frosted name strip at the bottom, over the image
            Text(vendor.businessName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
        }
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.Palette.textPrimary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: AppTheme.Palette.shadow, radius: 18, y: 12)
    }
}

// MARK: - Stats Card

struct VendorProfileStatsCard: View {
    let vendor: VendorProfile

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 18) {
                if vendor.reviewCount > 0 {
                    HStack {
                        Text(vendor.ratingText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("from \(vendor.reviewCount) reviews")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

            }
        }
    }
}

// MARK: - About Card

struct VendorProfileAboutCard: View {
    let vendor: VendorProfile

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                if !vendor.bio.isEmpty {
                    Text(vendor.bio)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                if !vendor.styleSummary.isEmpty {
                    Text(vendor.styleSummary)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }

                if !vendor.serviceArea.isEmpty || guestCapacityLabel != nil {
                    HStack(spacing: 14) {
                        if !vendor.serviceArea.isEmpty {
                            Label(vendor.serviceArea, systemImage: "mappin.and.ellipse")
                        }

                        if let capacity = guestCapacityLabel {
                            Label(capacity, systemImage: "person.2.fill")
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                }
            }
        }
    }

    private var guestCapacityLabel: String? {
        guard case .catering(let d) = vendor.categoryDetails else { return nil }
        if let min = d.minimumHeadcount, let max = d.maximumHeadcount {
            return "\(min)–\(max) guests"
        } else if let min = d.minimumHeadcount {
            return "Min \(min) guests"
        } else if let max = d.maximumHeadcount {
            return "Up to \(max) guests"
        }
        return nil
    }
}

// MARK: - Availability Card

struct VendorProfileAvailabilityCard: View {
    let vendor: VendorProfile

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                StatusBadge(title: vendor.availability.title, tone: vendor.availability.tone)

                Text(vendor.availabilitySummary.eventDateSupportLabel)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                if !vendor.availabilitySummary.nextOpeningLabel.isEmpty || !vendor.serviceArea.isEmpty {
                    HStack(spacing: 12) {
                        Label(vendor.availabilitySummary.nextOpeningLabel, systemImage: "calendar.badge.clock")
                        Label(vendor.serviceArea, systemImage: "mappin.and.ellipse")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                }

                if !vendor.availabilitySummary.windows.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(vendor.availabilitySummary.windows) { window in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(window.label)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                StatusBadge(title: window.state.title, tone: window.state.tone)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.Palette.elevatedSurface, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Package Card

struct VendorProfilePackageCard: View {
    let package: VendorPackage

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(package.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            if package.isHighlighted {
                                Text("Popular")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppTheme.Palette.elevatedSurface)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.Palette.accent, in: Capsule())
                            }
                        }
                    }

                    Spacer()

                    Text(package.priceLabel)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }

                if !package.description.isEmpty {
                    Text(package.description)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                if !package.includedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(package.includedItems, id: \.self) { item in
                            Label(item, systemImage: "checkmark")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Add-ons Card

struct VendorProfileAddOnsCard: View {
    let addOns: [VendorAddOn]

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(addOns) { addOn in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(addOn.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            if !addOn.description.isEmpty {
                                Text(addOn.description)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }
                        }

                        Spacer()

                        Text("+ \(addOn.priceLabel)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    }

                    if addOn.id != addOns.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Pricing Images Card

struct VendorProfilePricingImagesCard: View {
    let imagePaths: [String]
    @State private var selectedImageIndex: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(imagePaths.enumerated()), id: \.offset) { index, path in
                    Button {
                        selectedImageIndex = index
                    } label: {
                        AppSurface {
                            PlanoImage(
                                storagePath: path,
                                size: .thumbnail,
                                cornerRadius: AppTheme.smallCornerRadius,
                                contentMode: .fit
                            )
                            .frame(width: 260, height: 200)
                            .clipped()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedImageIndex != nil },
            set: { if !$0 { selectedImageIndex = nil } }
        )) {
            if let index = selectedImageIndex {
                GalleryImageViewer(storagePaths: imagePaths, startIndex: index)
            }
        }
    }
}

// MARK: - Services Card

struct VendorProfileServicesCard: View {
    let services: [String]

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(services, id: \.self) { service in
                    Label(service, systemImage: "checkmark")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }
            }
        }
    }
}

// MARK: - Gallery Card

struct VendorProfileGalleryCard: View {
    let galleryImages: [VendorGalleryImage]
    let businessName: String
    @State private var selectedImageIndex: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(galleryImages.enumerated()), id: \.element.id) { index, image in
                    Button {
                        selectedImageIndex = index
                    } label: {
                        AppSurface {
                            PlanoImage(
                                storagePath: image.storagePath,
                                size: .thumbnail,
                                cornerRadius: AppTheme.smallCornerRadius,
                                contentMode: .fill
                            )
                            .frame(width: 220, height: 160)
                            .clipped()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedImageIndex != nil },
            set: { if !$0 { selectedImageIndex = nil } }
        )) {
            if let index = selectedImageIndex {
                GalleryImageViewer(images: galleryImages, startIndex: index)
            }
        }
    }
}

// MARK: - Review Card

struct VendorProfileReviewCard: View {
    let review: VendorReviewEntry

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(review.author)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Text(String(repeating: "\u{2605}", count: review.rating))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppTheme.toneColor(.gold))
                }

                Text(review.quote)
                    .font(.title3)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("\(review.eventTypeLabel) • \(review.timelineLabel)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }
}

// MARK: - Policies Card

struct VendorProfilePoliciesCard: View {
    let policies: [VendorPolicy]

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(policies) { policy in
                    DisclosureGroup {
                        Text(policy.body)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .padding(.top, 4)
                    } label: {
                        Text(policy.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Social Card

struct VendorProfileSocialCard: View {
    let socialLinks: [VendorSocialLink]

    var body: some View {
        AppSurface {
            HStack(spacing: 12) {
                ForEach(socialLinks) { link in
                    if let destination = destination(for: link) {
                        Link(destination: destination) {
                            Label(link.label, systemImage: link.kind.symbolName)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private func destination(for link: VendorSocialLink) -> URL? {
        switch link.kind {
        case .instagram:
            let value = link.value.replacingOccurrences(of: "@", with: "")
            return URL(string: "https://instagram.com/\(value)")
        case .website:
            if link.value.hasPrefix("http://") || link.value.hasPrefix("https://") {
                return URL(string: link.value)
            }
            return URL(string: "https://\(link.value)")
        case .phone:
            return URL(string: "tel://\(link.value.filter(\.isNumber))")
        case .tiktok:
            let value = link.value.replacingOccurrences(of: "@", with: "")
            return URL(string: "https://www.tiktok.com/@\(value)")
        }
    }
}

// MARK: - Tags Card

struct VendorProfileTagsCard: View {
    let tags: [String]

    var body: some View {
        AppSurface {
            FlowLayout(spacing: 10) {
                ForEach(tags, id: \.self) { tag in
                    FilterChip(title: tag, isSelected: false)
                }
            }
        }
    }
}

// MARK: - Vendor Profile Skeleton

struct VendorProfileSkeleton: View {
    var body: some View {
        // Hero section
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SkeletonLine(width: 80, height: 24)
                    Spacer()
                    SkeletonLine(width: 90, height: 12)
                }

                SkeletonLine(width: 200, height: 28)

                SkeletonLine.medium

                SkeletonLine()
                    .frame(height: 12)
                SkeletonLine.long
                    .frame(height: 12)

                HStack(spacing: 10) {
                    SkeletonLine(width: 70, height: 28)
                    SkeletonLine(width: 80, height: 28)
                    SkeletonLine(width: 60, height: 28)
                }

            }
        }

        // Stats section
        AppSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SkeletonLine(width: 130, height: 12)
                    Spacer()
                    SkeletonLine(width: 100, height: 12)
                }

                HStack {
                    SkeletonLine(width: 40, height: 26)
                    SkeletonLine(width: 100, height: 14)
                }
            }
        }

        // Availability section
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SkeletonLine(width: 80, height: 24)
                    Spacer()
                    SkeletonLine(width: 100, height: 12)
                }

                SkeletonLine()
                    .frame(height: 12)
                SkeletonLine.long
                    .frame(height: 12)
            }
        }
    }
}
