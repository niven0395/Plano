import SwiftUI

struct VendorOnboardingServicesSlideView: View {
    let store: VendorOnboardingStore

    @State private var newServiceText = ""

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: "Your key services",
                subtitle: "List the services you offer so hosts can find you. You can add up to 6."
            )

            KeyServicesSection(
                services: $store.services,
                newServiceText: $newServiceText
            )
        }
    }
}
