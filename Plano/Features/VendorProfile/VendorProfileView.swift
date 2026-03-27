import SwiftUI

struct VendorProfileView: View {
    let store: VendorProfileStore

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

    private let imageHeight: Double = 200
    private let cornerRadius = AppTheme.cardCornerRadius

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let path = vendor.profileImagePath, !path.isEmpty {
                    PlanoImage(
                        storagePath: path,
                        size: .standard,
                        cornerRadius: 0,
                        contentMode: .fill
                    )
                    .frame(height: imageHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(AppTheme.toneBackground(vendor.category.accentTone))
                        .frame(height: imageHeight)
                        .overlay {
                            Image(systemName: vendor.category.symbolName)
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.toneColor(vendor.category.accentTone))
                        }
                }

                Text(vendor.badge)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(16)
            }

            Text(vendor.businessName)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .padding(22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.Palette.elevatedSurface,
                    AppTheme.Palette.elevatedSurface,
                    AppTheme.Palette.surface,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: cornerRadius)
        )
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
                HStack {
                    if let priceLabel = vendor.visiblePricingDetailLabel {
                        Label(priceLabel, systemImage: "creditcard.fill")
                    }


                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

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

                if !vendor.serviceArea.isEmpty {
                    Label(vendor.serviceArea, systemImage: "mappin.and.ellipse")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
            }
        }
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
                HStack {
                    Text(package.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Text(package.priceLabel)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }

                Text(package.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                if !package.includedItems.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(package.includedItems, id: \.self) { item in
                            FilterChip(title: item, isSelected: false)
                        }
                    }
                }
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
                                size: .standard,
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
