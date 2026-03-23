import SwiftUI

struct DecoratorBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MultiChoiceFilterGroup(
                title: "Service types",
                key: "serviceTypes",
                options: DecoratorDetails.serviceTypeOptions,
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Setup & teardown included",
                key: "setupTeardown",
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Materials provided",
                key: "materialsProvided",
                filterState: $filterState
            )
        }
    }
}
