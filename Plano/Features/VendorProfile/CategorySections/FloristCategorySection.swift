import SwiftUI

struct FloristCategorySection: View {
    let details: FloristDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.serviceTypes.isEmpty {
                    CategoryChipsGroup(title: "Services", items: details.serviceTypes)
                }

                if details.deliverySetupIncluded {
                    CategoryBooleanLabel(title: "Delivery & setup included", systemImage: "truck.box.fill")
                }

                if details.consultationIncluded {
                    CategoryBooleanLabel(title: "Consultation included", systemImage: "bubble.left.and.text.bubble.right")
                }
            }
        }
    }
}
