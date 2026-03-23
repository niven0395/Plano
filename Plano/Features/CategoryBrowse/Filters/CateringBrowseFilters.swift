import SwiftUI

struct CateringBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MultiChoiceFilterGroup(
                title: "Cuisine",
                key: "cuisineTypes",
                options: CateringDetails.cuisineOptions,
                filterState: $filterState
            )

            MultiChoiceFilterGroup(
                title: "Service style",
                key: "serviceStyles",
                options: CateringDetails.serviceStyleOptions,
                filterState: $filterState
            )

            MultiChoiceFilterGroup(
                title: "Dietary accommodations",
                key: "dietaryAccommodations",
                options: CateringDetails.dietaryOptions,
                filterState: $filterState
            )

            FilterGroup(title: "Headcount") {
                HStack(spacing: 12) {
                    Text("Guest count")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            let current = filterState.guestCount ?? 0
                            filterState.guestCount = max(current - 10, 0)
                            if filterState.guestCount == 0 { filterState.guestCount = nil }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.Palette.subdued)
                        }
                        .buttonStyle(.plain)

                        Text("\(filterState.guestCount ?? 0)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .frame(width: 44)

                        Button {
                            let current = filterState.guestCount ?? 0
                            filterState.guestCount = current + 10
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.Palette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
