import SwiftUI

struct FloristBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MultiChoiceFilterGroup(
                title: "Service types",
                key: "serviceTypes",
                options: FloristDetails.serviceTypeOptions,
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Delivery & setup included",
                key: "deliverySetup",
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Consultation included",
                key: "consultation",
                filterState: $filterState
            )
        }
    }
}
