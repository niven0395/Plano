import SwiftUI

struct AppetizerCategorySection: View {
    let details: AppetizerDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.serviceStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CategoryTextLabel(text: details.serviceStyle, systemImage: "fork.knife")
                }

                if !details.dietaryAccommodations.isEmpty {
                    CategoryChipsGroup(title: "Dietary accommodations", items: details.dietaryAccommodations)
                }

                if let min = details.minimumHeadcount {
                    CategoryCapacityRow(
                        text: "Minimum \(min) guests",
                        systemImage: "person.2.fill"
                    )
                }
            }
        }
    }
}
