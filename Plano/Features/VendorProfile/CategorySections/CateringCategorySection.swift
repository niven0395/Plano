import SwiftUI

struct CateringCategorySection: View {
    let details: CateringDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if hasServiceInfo {
                serviceCard
            }

            if !details.menuSections.isEmpty {
                menuCard
            }
        }
    }

    private var hasServiceInfo: Bool {
        !details.cuisineTypes.isEmpty
            || !details.serviceStyles.isEmpty
            || !details.dietaryAccommodations.isEmpty
            || details.tastingAvailable
            || details.servingStaffIncluded
            || details.tablewareIncluded
    }

    @ViewBuilder
    private var serviceCard: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.cuisineTypes.isEmpty {
                    CategoryChipsGroup(title: "Cuisines", items: details.cuisineTypes)
                }

                if !details.serviceStyles.isEmpty {
                    CategoryChipsGroup(title: "Service style", items: details.serviceStyles)
                }

                if !details.dietaryAccommodations.isEmpty {
                    CategoryChipsGroup(title: "Dietary accommodations", items: details.dietaryAccommodations)
                }

                if details.tastingAvailable {
                    CategoryBooleanLabel(title: "Tasting available", systemImage: "fork.knife")
                }

                if details.servingStaffIncluded {
                    CategoryBooleanLabel(title: "Serving staff included", systemImage: "person.3.fill")
                }

                if details.tablewareIncluded {
                    CategoryBooleanLabel(title: "Tableware included", systemImage: "wineglass.fill")
                }
            }
        }
    }

    private var menuCard: some View {
        let visibleSections = details.menuSections.filter { !$0.items.isEmpty }

        return AppSurface {
            VStack(alignment: .leading, spacing: 20) {
                Text("Menu")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                ForEach(Array(visibleSections.enumerated()), id: \.element.id) { index, section in
                    if index > 0 {
                        Divider()
                    }

                    menuSectionView(section)
                }
            }
        }
    }

    private func menuSectionView(_ section: MenuSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !section.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(section.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(section.items) { item in
                    menuItemView(item)
                }
            }
        }
    }

    private func menuItemView(_ item: MenuItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                if let priceCents = item.priceCents, priceCents > 0 {
                    Spacer()

                    Text(PricingAmountFormatter.currencyLabel(forCents: priceCents))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }
            }

            if let description = item.description,
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }
}