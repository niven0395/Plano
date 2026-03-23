import SwiftUI

struct PhotographyBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MultiChoiceFilterGroup(
                title: "Photo deliverables",
                key: "deliverables",
                options: PhotoVideoDetails.photoDeliverableOptions,
                filterState: $filterState
            )

            MultiChoiceFilterGroup(
                title: "Video deliverables",
                key: "videoDeliverables",
                options: PhotoVideoDetails.videoDeliverableOptions,
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Second shooter available",
                key: "secondShooter",
                filterState: $filterState
            )

            BrowseToggleRow(
                title: "Drone available",
                key: "droneAvailable",
                filterState: $filterState
            )
        }
    }
}
