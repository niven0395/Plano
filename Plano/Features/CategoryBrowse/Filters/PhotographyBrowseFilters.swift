import SwiftUI

struct PhotographyBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrowseToggleRow(
                title: "Drone available",
                key: "droneAvailable",
                filterState: $filterState
            )
        }
    }
}
