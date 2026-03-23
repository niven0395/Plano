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
                ToggleDefinition(key: "trial", title: "Trial included"),
                ToggleDefinition(key: "hairServices", title: "Hair services available"),
                ToggleDefinition(key: "groupRates", title: "Group rates available"),
            ]
        case .entertainer:
            [
                ToggleDefinition(key: "interactive", title: "Interactive entertainment"),
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
