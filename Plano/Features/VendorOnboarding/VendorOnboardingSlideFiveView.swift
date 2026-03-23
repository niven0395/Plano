import SwiftUI

struct VendorOnboardingSlideFiveView: View {
    let store: VendorOnboardingStore

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: "Set your availability",
                subtitle: "Let hosts know when you're free. You can always fine-tune this later."
            )

            AppSurface {
                WeeklyScheduleEditor(
                    schedulePreset: $store.schedulePreset,
                    availableDays: $store.availableDays
                )
            }

            AppSurface {
                BookingModeSelector(bookingMode: $store.bookingMode)
            }
        }
    }
}
