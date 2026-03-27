import SwiftUI

struct CategoryFilterSection: View {
    let category: VendorCategory
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        switch category {
        case .eventSpace:
            VenueBrowseFilters(filterState: $filterState)
        case .caterer:
            CateringBrowseFilters(filterState: $filterState)
        case .photographer:
            PhotographyBrowseFilters(filterState: $filterState)
        case .dj:
            DJBrowseFilters(filterState: $filterState)
        case .baker:
            BakerBrowseFilters(filterState: $filterState)
        case .florist:
            FloristBrowseFilters(filterState: $filterState)
        case .bartender:
            BartenderBrowseFilters(filterState: $filterState)
        case .makeupArtist:
            ToggleBrowseFilters(category: category, filterState: $filterState)
        case .decorator, .entertainer, .rental, .experienceStation,
             .appetizer, .desserts, .hairStylist, .studio,
             .photobooth:
            EmptyView()
        }
    }
}

// MARK: - Shared Filter Components

struct MultiChoiceFilterGroup: View {
    let title: String
    let key: String
    let options: [String]
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        FilterGroup(title: title) {
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        filterState.toggleMultiChoice(key: key, value: option)
                    } label: {
                        FilterChip(
                            title: option,
                            isSelected: filterState.selectedValues(for: key).contains(option)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct BrowseToggleRow: View {
    let title: String
    let key: String
    @Binding var filterState: CategoryBrowseFilterState

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)

            Spacer()

            Toggle(title, isOn: Binding(
                get: { filterState.isToggleOn(key) },
                set: { filterState.setToggle(key, value: $0) }
            ))
            .labelsHidden()
            .tint(AppTheme.Palette.accent)
        }
    }
}
