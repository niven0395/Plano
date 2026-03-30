import SwiftUI

struct CommonBrowseFilters: View {
    @Binding var filterState: CategoryBrowseFilterState
    let availableCities: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !availableCities.isEmpty {
                FilterGroup(title: "City") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Button {
                                filterState.selectedCity = nil
                            } label: {
                                FilterChip(title: "All cities", isSelected: filterState.selectedCity == nil)
                            }
                            .buttonStyle(.plain)

                            ForEach(availableCities, id: \.self) { city in
                                Button {
                                    filterState.selectedCity = filterState.selectedCity == city ? nil : city
                                } label: {
                                    FilterChip(title: city, isSelected: filterState.selectedCity == city)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            HStack(spacing: 12) {
                AvailabilityDateChip(date: $filterState.availabilityDate)


                Picker("Rating", selection: $filterState.ratingFilter) {
                    ForEach(SearchRatingFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker("Sort", selection: $filterState.sortMode) {
                    ForEach(SearchSortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Palette.textPrimary)
        }
    }
}

// MARK: - Filter Group

struct FilterGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)

            content
        }
    }
}
