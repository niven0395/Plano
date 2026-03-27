import SwiftUI

struct AvailabilityEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSurface {
                    BookingModeSelector(bookingMode: $store.draft.bookingMode)
                }

                AppSurface {
                    WeeklyScheduleEditor(
                        schedulePreset: $store.draft.schedulePreset,
                        availableDays: $store.draft.availableDays
                    )
                }

                AppSurface {
                    BookingWindowEditor(
                        leadTimeDays: $store.draft.leadTimeDays,
                        advanceBookingDays: $store.draft.advanceBookingDays
                    )
                }

                AppSurface {
                    SchedulingModeEditor(store: store)
                }

                NavigationLink(value: DiscoveryRoute.vendorBlockDates) {
                    AppSurface {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.minus")
                                .font(.title3)
                                .foregroundStyle(AppTheme.toneColor(.coral))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Block Dates")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)
                                Text("Block a range or multiple specific dates at once")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                        }
                    }
                }
                .buttonStyle(.plain)

                AppSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Payment preference")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Set the payment route hosts should expect once a date moves forward.")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }

                        Picker("Payment preference", selection: $store.draft.paymentMode) {
                            ForEach(PaymentMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .hapticFeedback(.selection, trigger: store.draft.paymentMode)
                    }
                }

                Button(store.loadingState.isLoading ? "Saving..." : "Save availability & booking", action: save)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(store.loadingState.isLoading)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Availability & Booking")
        .navigationBarTitleDisplayMode(.inline)
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Availability saved") {
            store.lastSaveOutcome = .idle
        }
    }

    private func save() {
        Task {
            await store.save()
            if store.lastSaveOutcome == .saved {
                dismiss()
            }
        }
    }
}
