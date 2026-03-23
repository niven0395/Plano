import SwiftUI

struct VendorOnboardingSlideThreeView: View {
    let store: VendorOnboardingStore

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: CategoryDetails.empty(for: store.selectedCategory).sectionTitle,
                subtitle: "Details specific to \(store.selectedCategory.title.lowercased()) that help hosts decide."
            )

            OnboardingCategoryDetailsDispatcher(
                category: store.selectedCategory,
                categoryDetails: $store.categoryDetails
            )
        }
    }
}
