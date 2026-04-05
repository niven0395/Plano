import SwiftUI

struct CategoryBrowseResultCard: View {
    let result: SearchResultSnapshot
    var showsCategoryTag = false

    private let imageHeight: Double = 220
    private let cornerRadius = AppTheme.cardCornerRadius

    var body: some View {
        let vendor = result.vendor
        let imagePath = vendor.listingImagePath.flatMap({ $0.isEmpty ? nil : $0 })
            ?? vendor.profileImagePath

        ZStack(alignment: .bottom) {
            // Image layer
            Group {
                if let path = imagePath, !path.isEmpty {
                    PlanoImage(
                        storagePath: path,
                        size: .thumbnail,
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

            // Tag capsule — top-leading
            Label(
                showsCategoryTag ? vendor.category.title : vendor.city,
                systemImage: showsCategoryTag ? vendor.category.symbolName : "mappin.and.ellipse"
            )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Frosted name strip
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vendor.businessName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    if let subtitle = CategoryDetailText.highlight(for: vendor) {
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .opacity(0.85)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    if vendor.reviewCount > 0 {
                        Label(vendor.ratingText, systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                    }

                    if let priceLabel = vendor.visibleStartingPriceLabel {
                        Text(priceLabel)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
            }
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

// MARK: - Category Detail Text Helper

private enum CategoryDetailText {
    static func highlight(for vendor: VendorProfile) -> String? {
        guard let details = vendor.categoryDetails else { return nil }

        switch details {
        case .venue(let d):
            var parts: [String] = []
            if let seated = d.seatedCapacity { parts.append("Seats \(seated)") }
            if let standing = d.standingCapacity { parts.append("Standing \(standing)") }
            if !d.venueStyle.isEmpty { parts.append(d.venueStyle) }
            return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")

        case .catering(let d):
            let cuisines = d.cuisineTypes.prefix(3).joined(separator: ", ")
            return cuisines.isEmpty ? nil : cuisines

        case .photoVideo(let d):
            let items = d.deliverables.prefix(3).joined(separator: ", ")
            return items.isEmpty ? nil : items

        case .dj(let d):
            let genres = d.musicGenres.prefix(3).joined(separator: ", ")
            return genres.isEmpty ? nil : genres

        case .baker(let d):
            let items = d.specialties.prefix(3).joined(separator: ", ")
            return items.isEmpty ? nil : items

        case .florist(let d):
            let items = d.serviceTypes.prefix(3).joined(separator: ", ")
            return items.isEmpty ? nil : items

        case .decorator(let d):
            let items = d.serviceTypes.prefix(3).joined(separator: ", ")
            return items.isEmpty ? nil : items

        case .bartender(let d):
            let items = d.barTypes.prefix(3).joined(separator: ", ")
            return items.isEmpty ? nil : items

        default:
            return vendor.styleSummary.isEmpty ? nil : vendor.styleSummary
        }
    }
}

// MARK: - Reason Row

private struct FlexibleBrowseReasonRow: View {
    let reasons: [SearchRankingReason]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(reasons, id: \.self) { reason in
                Text(reason.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.toneColor(reason.tone))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(AppTheme.toneBackground(reason.tone), in: Capsule())
            }
        }
    }
}

// MARK: - Skeleton

struct CategoryBrowseResultCardSkeleton: View {
    var body: some View {
        SkeletonRect(height: 220)
            .overlay(alignment: .bottom) {
                HStack {
                    SkeletonLine(width: 140, height: 14)
                    Spacer()
                    SkeletonLine(width: 60, height: 14)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .clipShape(.rect(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(color: AppTheme.Palette.shadow, radius: 18, y: 12)
    }
}
