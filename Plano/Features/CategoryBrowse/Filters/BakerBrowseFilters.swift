import SwiftUI

struct BakerBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MultiChoiceFilterGroup(
                title: "Specialties",
                key: "specialties",
                options: BakerDetails.specialtyOptions,
                filterState: $filterState
            )

            MultiChoiceFilterGroup(
                title: "Dietary options",
                key: "dietaryOptions",
                options: BakerDetails.availableDietaryOptions,
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Tasting available",
                key: "tasting",
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
