import SwiftUI

struct ExperienceStationCategorySection: View {
    let details: ExperienceStationDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.stationType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CategoryTextLabel(text: details.stationType, systemImage: "sparkles")
                }

                if details.setupIncluded {
                    CategoryBooleanLabel(title: "Setup included", systemImage: "hammer.fill")
                }

                if details.equipmentProvided {
                    CategoryBooleanLabel(title: "Equipment provided", systemImage: "wrench.and.screwdriver.fill")
                }
            }
        }
    }
}
