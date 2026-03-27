import SwiftUI

struct CateringBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MultiChoiceFilterGroup(
                title: "Cuisine",
                key: "cuisineTypes",
                options: CateringDetails.browseCuisineOptions,
                filterState: $filterState
            )

            MultiChoiceFilterGroup(
                title: "Dietary",
                key: "dietaryAccommodations",
                options: CateringDetails.browseDietaryOptions,
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Delivery available",
                key: "delivery",
                filterState: $filterState
            )
        }
    }
}
