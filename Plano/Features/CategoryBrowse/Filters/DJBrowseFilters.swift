import SwiftUI

struct DJBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MultiChoiceFilterGroup(
                title: "Music genres",
                key: "musicGenres",
                options: DJDetails.genreOptions,
                filterState: $filterState
            )
        }
    }
}
