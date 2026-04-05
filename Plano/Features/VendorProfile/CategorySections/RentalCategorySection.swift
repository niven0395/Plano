import SwiftUI

struct RentalCategorySection: View {
    let details: RentalDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.rentalCategories.isEmpty {
                    CategoryChipsGroup(title: "Available rentals", items: details.rentalCategories)
                }

                if details.deliveryPickupIncluded {
                    CategoryBooleanLabel(title: "Delivery & pickup included", systemImage: "truck.box.fill")
                }

                if details.setupIncluded {
                    CategoryBooleanLabel(title: "Setup included", systemImage: "hammer.fill")
                }
            }
        }
    }
}
