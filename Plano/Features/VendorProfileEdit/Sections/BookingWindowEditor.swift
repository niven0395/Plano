import SwiftUI

struct BookingWindowEditor: View {
    @Binding var leadTimeDays: Int
    @Binding var advanceBookingDays: Int

    private let leadTimeOptions = [0, 1, 3, 7, 14, 30]
    private let advanceBookingOptions = [30, 90, 180, 365]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Booking window")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("Set how much notice you need and how far ahead hosts can lock dates.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Minimum notice")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Text(leadTimeLabel(for: leadTimeDays))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(leadTimeOptions, id: \.self) { option in
                            Button {
                                leadTimeDays = option
                            } label: {
                                FilterChip(
                                    title: leadTimeLabel(for: option),
                                    isSelected: leadTimeDays == option
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Book up to")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    Text(advanceBookingLabel(for: advanceBookingDays))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(advanceBookingOptions, id: \.self) { option in
                            Button {
                                advanceBookingDays = option
                            } label: {
                                FilterChip(
                                    title: advanceBookingLabel(for: option),
                                    isSelected: advanceBookingDays == option
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func leadTimeLabel(for days: Int) -> String {
        switch days {
        case 0:
            "None"
        case 1:
            "1 day"
        default:
            "\(days) days"
        }
    }

    private func advanceBookingLabel(for days: Int) -> String {
        switch days {
        case 30:
            "1 month"
        case 90:
            "3 months"
        case 180:
            "6 months"
        case 365:
            "1 year"
        default:
            "\(days) days"
        }
    }
}
