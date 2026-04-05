import SwiftUI

struct DessertsCategorySection: View {
    let details: DessertsDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.specialties.isEmpty {
                    CategoryChipsGroup(title: "Specialties", items: details.specialties)
                }

                if !details.dietaryAccommodations.isEmpty {
                    CategoryChipsGroup(title: "Dietary accommodations", items: details.dietaryAccommodations)
                }

                if let min = details.servesMinimumHeadcount {
                    CategoryCapacityRow(
                        text: "Minimum \(min) guests",
                        systemImage: "person.2.fill"
                    )
                }
            }
        }
    }
}
