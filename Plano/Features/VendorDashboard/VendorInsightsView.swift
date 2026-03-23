import SwiftUI

struct VendorInsightsView: View {
    @State private var store: VendorInsightsStore

    init(analyticsService: any AnalyticsServiceProtocol) {
        _store = State(initialValue: VendorInsightsStore(analyticsService: analyticsService))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    title: "Insights",
                    subtitle: "How hosts discover and engage with your listing"
                )

                InsightsPeriodPicker(selection: $store.selectedPeriod)

                switch store.loadingState {
                case .idle, .loading:
                    InsightsLoadingPlaceholder()
                case .loaded:
                    if let insights = store.insights {
                        InsightsDiscoverySection(store: store, insights: insights)
                        InsightsEngagementSection(store: store, insights: insights)
                        InsightsConversionSection(store: store, insights: insights)
                        InsightsRevenueSection(store: store, insights: insights)

                        if let benchmarks = insights.benchmarks {
                            CategoryBenchmarkCard(
                                conversion: insights.conversion,
                                benchmarks: benchmarks
                            )
                        }
                    }
                case .failed(let message):
                    EmptyStateCard(
                        symbolName: "exclamationmark.triangle",
                        title: "Couldn't load insights",
                        message: message
                    )
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadIfNeeded() }
    }
}

// MARK: - Period Picker

private struct InsightsPeriodPicker: View {
    @Binding var selection: InsightsPeriodSelection

    var body: some View {
        HStack(spacing: 8) {
            ForEach(InsightsPeriodSelection.allCases) { period in
                Button {
                    selection = period
                } label: {
                    FilterChip(
                        title: period.rawValue,
                        isSelected: selection == period
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Loading Placeholder

private struct InsightsLoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                AppSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Palette.chrome)
                            .frame(width: 100, height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Palette.chrome)
                            .frame(width: 60, height: 24)
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

// MARK: - Discovery Section

private struct InsightsDiscoverySection: View {
    let store: VendorInsightsStore
    let insights: VendorInsightsRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Discovery")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            HStack(spacing: 12) {
                InsightsMetricCard(
                    label: "Profile views",
                    value: store.profileViewsLabel,
                    trend: insights.discovery.profileViewsTrend,
                    tone: .blue
                )
                InsightsMetricCard(
                    label: "Impressions",
                    value: store.impressionsLabel,
                    trend: insights.discovery.searchImpressionsTrend,
                    tone: .sand
                )
            }

            InsightsMetricCard(
                label: "Click-through rate",
                value: store.ctrLabel,
                trend: insights.discovery.clickThroughRateTrend,
                tone: .sage
            )

            TopSearchQueriesCard(queries: insights.discovery.topSearchQueries)
        }
    }
}

// MARK: - Engagement Section

private struct InsightsEngagementSection: View {
    let store: VendorInsightsStore
    let insights: VendorInsightsRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Engagement")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            InsightsMetricCard(
                label: "Save rate",
                value: store.saveRateLabel,
                trend: insights.engagement.saveRateTrend,
                tone: .coral
            )
        }
    }
}

// MARK: - Conversion Section

private struct InsightsConversionSection: View {
    let store: VendorInsightsStore
    let insights: VendorInsightsRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Conversion")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            HStack(spacing: 12) {
                InsightsMetricCard(
                    label: "Message rate",
                    value: store.messageRateLabel,
                    trend: insights.conversion.messageInitiationRateTrend,
                    tone: .blue
                )
                InsightsMetricCard(
                    label: "Booking rate",
                    value: store.bookingRateLabel,
                    trend: insights.conversion.bookingRequestRateTrend,
                    tone: .sage
                )
            }

            HStack(spacing: 12) {
                InsightsMetricCard(
                    label: "Conversion",
                    value: store.conversionRateLabel,
                    trend: insights.conversion.leadToBookingConversionTrend,
                    tone: .gold
                )
                InsightsMetricCard(
                    label: "Avg response",
                    value: store.responseTimeLabel,
                    trend: insights.conversion.avgResponseMinutesTrend,
                    tone: .sand
                )
            }
        }
    }
}

// MARK: - Revenue Section

private struct InsightsRevenueSection: View {
    let store: VendorInsightsStore
    let insights: VendorInsightsRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Revenue")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            InsightsMetricCard(
                label: "Total revenue",
                value: store.revenueLabel,
                trend: insights.revenue.totalRevenueTrend,
                tone: .sage
            )

            HStack(spacing: 12) {
                InsightsMetricCard(
                    label: "Avg booking",
                    value: store.avgBookingValueLabel,
                    trend: insights.revenue.avgBookingValueTrend,
                    tone: .blue
                )
                InsightsMetricCard(
                    label: "Bookings",
                    value: store.bookingVolumeLabel,
                    trend: insights.revenue.bookingVolumeTrend,
                    tone: .gold
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        VendorInsightsView(
            analyticsService: UnavailableAnalyticsService(message: "Preview")
        )
    }
}
