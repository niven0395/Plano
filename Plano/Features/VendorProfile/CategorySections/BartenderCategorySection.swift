import SwiftUI

struct BartenderCategorySection: View {
    let details: BartenderDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.barTypes.isEmpty {
                    CategoryChipsGroup(title: "Bar types", items: details.barTypes)
                }

                if details.signatureCocktails {
                    CategoryBooleanLabel(title: "Signature cocktails", systemImage: "wineglass.fill")
                }

                if details.equipmentProvided {
                    CategoryBooleanLabel(title: "Equipment provided", systemImage: "wrench.and.screwdriver.fill")
                }

                if details.ingredientsIncluded {
                    CategoryBooleanLabel(title: "Ingredients included", systemImage: "basket.fill")
                }
            }
        }
    }
}
