import SwiftUI

struct CategoryBenchmarkCard: View {
    let conversion: VendorInsightsRecord.ConversionInsights
    let benchmarks: VendorInsightsRecord.CategoryBenchmarkInsights

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                Text("vs \(benchmarks.category) average")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                VStack(spacing: 12) {
                    if let catResponse = benchmarks.categoryAvgResponseMinutes,
                       let myResponse = conversion.avgResponseMinutes {
                        BenchmarkRow(
                            label: "Response time",
                            yours: formatMinutes(myResponse),
                            average: formatMinutes(catResponse),
                            yoursIsBetter: myResponse < catResponse
                        )
                    }

                    if let catConversion = benchmarks.categoryAvgConversionRate {
                        BenchmarkRow(
                            label: "Conversion rate",
                            yours: formatPercent(conversion.leadToBookingConversion),
                            average: formatPercent(catConversion),
                            yoursIsBetter: conversion.leadToBookingConversion > catConversion
                        )
                    }
                }
            }
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hours = minutes / 60.0
        if hours < 1 { return "\(Int(minutes))m" }
        return String(format: "%.1fh", hours)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

private struct BenchmarkRow: View {
    let label: String
    let yours: String
    let average: String
    let yoursIsBetter: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Palette.subdued)

            HStack(spacing: 16) {
                BenchmarkValue(label: "You", value: yours, tone: yoursIsBetter ? .sage : .coral)
                BenchmarkValue(label: "Category avg", value: average, tone: .blue)
            }
        }
    }
}

private struct BenchmarkValue: View {
    let label: String
    let value: String
    let tone: AccentTone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.toneColor(tone))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
