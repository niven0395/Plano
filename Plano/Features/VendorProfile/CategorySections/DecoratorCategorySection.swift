import SwiftUI

struct DecoratorCategorySection: View {
    let details: DecoratorDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.serviceTypes.isEmpty {
                    CategoryChipsGroup(title: "Services", items: details.serviceTypes)
                }

                if details.setupTeardownIncluded {
                    CategoryBooleanLabel(title: "Setup & teardown included", systemImage: "hammer.fill")
                }

                if details.materialsProvided {
                    CategoryBooleanLabel(title: "Materials provided", systemImage: "shippingbox.fill")
                }
            }
        }
    }
}
