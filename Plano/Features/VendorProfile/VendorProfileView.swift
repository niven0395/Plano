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

    private let cornerRadius = AppTheme.cardCornerRadius

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heroImage
                .aspectRatio(4.0 / 3.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppTheme.Palette.textPrimary.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: AppTheme.Palette.shadow, radius: 18, y: 12)

            VStack(alignment: .leading, spacing: 14) {
                Text(vendor.businessName)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                signalRow

                if !chips.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(AppTheme.Palette.chipFill, in: Capsule())
                                .overlay {
                                    Capsule().stroke(AppTheme.Palette.border, lineWidth: 1)
                                }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var heroImage: some View {
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
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.toneColor(vendor.category.accentTone))
                }
        }
    }

    private var signalRow: some View {
        SignalRow(items: [
            vendor.reviewCount > 0
                ? .rating(value: vendor.ratingText, count: vendor.reviewCount)
                : nil,
            vendor.responseTime.isEmpty
                ? nil
                : .text("Responds in \(vendor.responseTime)"),
            vendor.badge.isEmpty
                ? nil
                : .badge(vendor.badge, tone: .sage),
        ])
    }

    private var chips: [String] {
        var result: [String] = [vendor.displayCategoryTitle]
        if !vendor.serviceArea.isEmpty {
            result.append(vendor.serviceArea)
        } else if !vendor.city.isEmpty {
            result.append(vendor.city)
        }
        return result
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

    @State private var showsAllInclusions = false

    private let inclusionLimit = 3

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 14) {
            if package.isHighlighted {
                Label("Most booked", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.accentForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.Palette.accent, in: Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(package.title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .tracking(-0.4)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Starting at")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.subdued)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(package.priceLabel)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }
            }

            if !package.description.isEmpty {
                Text(package.description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !package.includedItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleInclusions, id: \.self) { item in
                        Label {
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                .font(.footnote)
                        }
                    }

                    if package.includedItems.count > inclusionLimit {
                        Button {
                            withAnimation(.snappy) {
                                showsAllInclusions.toggle()
                            }
                        } label: {
                            Text(showsAllInclusions
                                 ? "Show less"
                                 : "See all \(package.includedItems.count) inclusions")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }
        }

        return content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                package.isHighlighted
                    ? AnyShapeStyle(AppTheme.toneBackground(.gold).opacity(0.6))
                    : AnyShapeStyle(AppTheme.Palette.surface),
                in: .rect(cornerRadius: AppTheme.cardCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(
                        package.isHighlighted
                            ? AppTheme.toneColor(.gold).opacity(0.5)
                            : AppTheme.Palette.border,
                        lineWidth: package.isHighlighted ? 1.5 : 1
                    )
            }
            .shadow(color: AppTheme.Palette.shadow, radius: 18, y: 12)
    }

    private var visibleInclusions: [String] {
        if showsAllInclusions || package.includedItems.count <= inclusionLimit {
            return package.includedItems
        }
        return Array(package.includedItems.prefix(inclusionLimit))
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
        Group {
            if galleryImages.count >= 3 {
                mosaicLayout
            } else {
                horizontalRail
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

    private var mosaicLayout: some View {
        VStack(spacing: 10) {
            heroTile

            if galleryImages.count > 1 {
                let pairs = gridPairs
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    HStack(spacing: 10) {
                        mosaicTile(pair.0)
                        if let second = pair.1 {
                            mosaicTile(second)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var heroTile: some View {
        Button {
            selectedImageIndex = 0
        } label: {
            galleryThumbnail(index: 0)
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: AppTheme.smallCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                        .stroke(AppTheme.Palette.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gallery photo 1")
    }

    private func mosaicTile(_ entry: GridEntry) -> some View {
        Button {
            selectedImageIndex = entry.index
        } label: {
            galleryThumbnail(index: entry.index)
                .aspectRatio(1.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: AppTheme.smallCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                        .stroke(AppTheme.Palette.border, lineWidth: 1)
                }
                .overlay(alignment: .bottomTrailing) {
                    if entry.showsSeeAll, let remaining = entry.remainingCount {
                        Text("+\(remaining) more")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(10)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gallery photo \(entry.index + 1)")
    }

    private func galleryThumbnail(index: Int) -> some View {
        PlanoImage(
            storagePath: galleryImages[index].storagePath,
            size: .thumbnail,
            cornerRadius: 0,
            contentMode: .fill
        )
    }

    /// Builds rows of up to 2 tiles, showing a maximum of 5 gallery images
    /// (hero + 2 rows of 2). The last visible tile may show "+N more".
    private var gridPairs: [(GridEntry, GridEntry?)] {
        let tileLimit = 4 // after the hero (index 0)
        let remainingCount = galleryImages.count - 1
        let visibleCount = min(remainingCount, tileLimit)
        let visibleIndices = Array(1...visibleCount).map { $0 }
        let hiddenCount = remainingCount - visibleCount

        var entries: [GridEntry] = []
        for (offset, index) in visibleIndices.enumerated() {
            let isLast = (offset == visibleIndices.count - 1)
            let showsSeeAll = isLast && hiddenCount > 0
            entries.append(GridEntry(
                index: index,
                showsSeeAll: showsSeeAll,
                remainingCount: showsSeeAll ? hiddenCount : nil
            ))
        }

        var pairs: [(GridEntry, GridEntry?)] = []
        var iterator = entries.makeIterator()
        while let first = iterator.next() {
            let second = iterator.next()
            pairs.append((first, second))
        }
        return pairs
    }

    private var horizontalRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(galleryImages.enumerated()), id: \.element.id) { index, _ in
                    Button {
                        selectedImageIndex = index
                    } label: {
                        galleryThumbnail(index: index)
                            .frame(width: 240, height: 180)
                            .clipShape(.rect(cornerRadius: AppTheme.smallCornerRadius))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                                    .stroke(AppTheme.Palette.border, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Gallery photo \(index + 1)")
                }
            }
        }
    }

    private struct GridEntry {
        let index: Int
        let showsSeeAll: Bool
        let remainingCount: Int?
    }
}

// MARK: - Review Card

struct VendorProfileReviewCard: View {
    let review: VendorReviewEntry

    private var monogram: String {
        guard let first = review.author.trimmingCharacters(in: .whitespaces).first else {
            return "?"
        }
        return String(first).uppercased()
    }

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppTheme.Palette.textPrimary.opacity(0.18))
                    .accessibilityHidden(true)

                Text(review.quote)
                    .font(.body)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.toneBackground(.sand))
                        Text(monogram)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.toneColor(.sand))
                    }
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.author)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("\(review.eventTypeLabel) · \(review.timelineLabel)")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: index < review.rating ? "star.fill" : "star")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    index < review.rating
                                        ? AppTheme.toneColor(.gold)
                                        : AppTheme.Palette.subdued.opacity(0.4)
                                )
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(review.rating) out of 5 stars")
                }
            }
        }
    }
}

// MARK: - Policies Card

struct VendorProfilePoliciesCard: View {
    let policies: [VendorPolicy]

    @State private var selectedPolicy: VendorPolicy?

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(policies) { policy in
                Button {
                    selectedPolicy = policy
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: symbolName(for: policy.title))
                            .font(.title3.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Palette.elevatedSurface, in: Circle())
                            .accessibilityHidden(true)

                        Text(policy.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(policy.body)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppTheme.Palette.surface, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                            .stroke(AppTheme.Palette.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Double tap to read full policy")
            }
        }
        .sheet(item: $selectedPolicy) { policy in
            VendorPolicyDetailSheet(policy: policy)
        }
    }

    private func symbolName(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("cancel") { return "xmark.circle" }
        if lower.contains("refund") { return "arrow.uturn.backward.circle" }
        if lower.contains("deposit") || lower.contains("payment") { return "creditcard" }
        if lower.contains("travel") || lower.contains("location") { return "mappin.and.ellipse" }
        if lower.contains("weather") { return "cloud.sun" }
        if lower.contains("guest") || lower.contains("head") { return "person.2" }
        if lower.contains("time") || lower.contains("hour") { return "clock" }
        return "doc.text"
    }
}

struct VendorPolicyDetailSheet: View {
    let policy: VendorPolicy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(policy.body)
                    .font(.body)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.screenPadding)
            }
            .background(AppBackdrop())
            .navigationTitle(policy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
