import SwiftUI

struct BakerCategorySection: View {
    let details: BakerDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.specialties.isEmpty {
                    CategoryChipsGroup(title: "Specialties", items: details.specialties)
                }

                if !details.dietaryOptions.isEmpty {
                    CategoryChipsGroup(title: "Dietary options", items: details.dietaryOptions)
                }

                if details.tastingAvailable {
                    CategoryBooleanLabel(title: "Tasting available", systemImage: "fork.knife")
                }

                if details.deliveryAvailable {
                    CategoryBooleanLabel(title: "Delivery available", systemImage: "shippingbox.fill")
                }
            }
        }
    }
}
