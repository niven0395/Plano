import SwiftUI

struct StudioCategorySection: View {
    let details: StudioDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.studioType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CategoryTextLabel(text: details.studioType, systemImage: "building.fill")
                }

                if let max = details.maxOccupancy {
                    CategoryCapacityRow(
                        text: "Up to \(max) people",
                        systemImage: "person.2.fill"
                    )
                }

                if details.equipmentIncluded {
                    CategoryBooleanLabel(title: "Equipment included", systemImage: "wrench.and.screwdriver.fill")
                }
            }
        }
    }
}
