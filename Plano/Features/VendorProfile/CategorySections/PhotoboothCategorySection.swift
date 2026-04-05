import SwiftUI

struct PhotoboothCategorySection: View {
    let details: PhotoboothDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.boothTypes.isEmpty {
                    CategoryChipsGroup(title: "Booth types", items: details.boothTypes)
                }

                if details.propsIncluded {
                    CategoryBooleanLabel(title: "Props included", systemImage: "theatermask.and.paintbrush.fill")
                }

                if details.attendantIncluded {
                    CategoryBooleanLabel(title: "Attendant included", systemImage: "person.fill")
                }
            }
        }
    }
}
