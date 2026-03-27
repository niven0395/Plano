import SwiftUI

struct CategoryBrowseResultCard: View {
    let result: SearchResultSnapshot

    var body: some View {
        let vendor = result.vendor

        AppSurface {
            VStack(alignment: .leading, spacing: 18) {
                VendorArtworkPanel(
                    profileImagePath: vendor.profileImagePath,
                    listingImagePath: vendor.listingImagePath,
                    tone: vendor.category.accentTone,
                    symbolName: vendor.category.symbolName,
                    height: 160
                )

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(vendor.businessName)
                            .font(.system(size: 24, weight: .regular))
                            .tracking(-0.6)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        HStack(spacing: 8) {
                            Label(vendor.city, systemImage: "mappin.and.ellipse")

                            if let priceLabel = vendor.visibleStartingPriceLabel {
                                Label(priceLabel, systemImage: "creditcard.fill")
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .padding(.trailing, 34)
                    }

                    Spacer()

                    if vendor.reviewCount > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(vendor.ratingText)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("\(vendor.reviewCount) reviews")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                        }
                    }
                }

                CategoryDetailHighlight(vendor: vendor)
            }
        }
    }
}

// MARK: - Category-Specific Detail Highlight

private struct CategoryDetailHighlight: View {
    let vendor: VendorProfile

    var body: some View {
        if let text = highlightText {
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)
                .lineLimit(2)
        }
    }

    private var highlightText: String? {
        guard let details = vendor.categoryDetails else { return nil }

        switch details {
        case .venue(let d):
            var parts: [String] = []
            if let seated = d.seatedCapacity { parts.append("Seats \(seated)") }
            if let standing = d.standingCapacity { parts.append("Standing \(standing)") }
            if !d.venueStyle.isEmpty { parts.append(d.venueStyle) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")

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
        AppSurface {
            VStack(alignment: .leading, spacing: 18) {
                SkeletonRect(height: 160)

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonLine.long
                        SkeletonLine.medium
                    }

                    Spacer()
                }

                SkeletonLine.medium
            }
        }
    }
}
