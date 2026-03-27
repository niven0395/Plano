import SwiftUI

struct FloristBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrowseToggleRow(
                title: "Delivery & setup included",
                key: "deliverySetup",
                filterState: $filterState
            )
        }
    }
}
