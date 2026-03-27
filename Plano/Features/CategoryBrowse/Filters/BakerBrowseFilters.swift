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

            BrowseToggleRow(
                title: "Delivery available",
                key: "delivery",
                filterState: $filterState
            )
        }
    }
}
