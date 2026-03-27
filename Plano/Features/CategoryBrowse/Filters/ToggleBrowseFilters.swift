import SwiftUI

struct ToggleBrowseFilters: View {
    let category: VendorCategory
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(toggleDefinitions, id: \.key) { definition in
                BrowseToggleRow(
                    title: definition.title,
                    key: definition.key,
                    filterState: $filterState
                )
            }
        }
    }

    private var toggleDefinitions: [ToggleDefinition] {
        switch category {
        case .makeupArtist:
            [
                ToggleDefinition(key: "travelToVenue", title: "Travels to venue"),
            ]
        default:
            []
        }
    }
}

private struct ToggleDefinition {
    let key: String
    let title: String
}
