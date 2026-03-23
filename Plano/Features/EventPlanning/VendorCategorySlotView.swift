import SwiftUI

struct VendorCategorySlotView: View {
    let slot: EventPlanningStore.CategorySlot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppSurface(style: slot.vendor == nil ? .regular : .highlighted) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        Image(systemName: slot.category.symbolName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.toneColor(slot.category.accentTone))
                            .frame(width: AppTheme.iconFrameSize, height: AppTheme.iconFrameSize)
                            .background(AppTheme.toneBackground(slot.category.accentTone), in: RoundedRectangle(cornerRadius: AppTheme.compactCornerRadius, style: .continuous))

                        Spacer()

                        if let stage = slot.bookingStage {
                            StatusBadge(title: stage.title, tone: stage.tone)
                        } else if slot.isSuggested {
                            Text("Suggested")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                        }
                    }

                    Text(slot.category.singularTitle)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    if let vendor = slot.vendor {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(vendor.businessName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text(vendor.visibleStartingPriceLabel ?? "Pricing on request")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    } else {
                        Label("Find a \(slot.category.singularTitle.lowercased())", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
