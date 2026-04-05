import SwiftUI

struct DJCategorySection: View {
    let details: DJDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.musicGenres.isEmpty {
                    CategoryChipsGroup(title: "Music genres", items: details.musicGenres)
                }

                if details.mcServicesAvailable {
                    CategoryBooleanLabel(title: "MC services available", systemImage: "mic.fill")
                }

                if details.lightingPackageAvailable {
                    CategoryBooleanLabel(title: "Lighting package available", systemImage: "lightbulb.fill")
                }
            }
        }
    }
}
