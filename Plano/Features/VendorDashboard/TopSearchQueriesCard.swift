import SwiftUI

struct TopSearchQueriesCard: View {
    let queries: [VendorInsightsRecord.SearchQueryEntry]

    var body: some View {
        if queries.isEmpty {
            EmptyStateCard(
                symbolName: "magnifyingglass",
                title: "No search data yet",
                message: "Search queries that lead hosts to your profile will appear here."
            )
        } else {
            AppSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Top searches")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    ForEach(queries.prefix(5), id: \.query) { entry in
                        QueryRow(entry: entry)
                    }
                }
            }
        }
    }
}

private struct QueryRow: View {
    let entry: VendorInsightsRecord.SearchQueryEntry

    var body: some View {
        HStack {
            Text(entry.query)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 12)

            Text("\(entry.count)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Palette.subdued)
                .monospacedDigit()
        }
    }
}
