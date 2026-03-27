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
        }
    }
}
