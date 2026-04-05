import SwiftUI

struct EventTimeRangeBookingSection: View {
    let vendor: VendorProfile
    @Bindable var store: VendorBookingRequestStore

    private var earliestDate: Date {
        Calendar.current.date(byAdding: .day, value: vendor.leadTimeDays, to: .now) ?? .now
    }

    private var latestDate: Date {
        Calendar.current.date(byAdding: .day, value: vendor.advanceBookingDays, to: .now) ?? .now
    }

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event date")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    DatePicker(
                        "Event date",
                        selection: Binding(
                            get: { store.selectedBookingDate ?? earliestDate },
                            set: { store.selectedBookingDate = $0 }
                        ),
                        in: earliestDate...latestDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start time")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textSecondary)

                        DatePicker(
                            "Start time",
                            selection: Binding(
                                get: { store.requestedStartTime ?? .now },
                                set: { store.requestedStartTime = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("End time")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textSecondary)

                        DatePicker(
                            "End time",
                            selection: Binding(
                                get: { store.requestedEndTime ?? .now },
                                set: { store.requestedEndTime = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }

                    Spacer()
                }

                Button("Request Booking") {
                    store.isPresentingBookingSheet = true
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!store.canSubmitBooking)
            }
        }
        .onChange(of: store.selectedBookingDate) { _, _ in
        }
    }
}
