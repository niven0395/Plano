import SwiftUI

struct BartenderBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MultiChoiceFilterGroup(
                title: "Bar types",
                key: "barTypes",
                options: BartenderDetails.barTypeOptions,
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Equipment provided",
                key: "equipment",
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Ingredients included",
                key: "ingredients",
                filterState: $filterState
            )
        }
    }
}
