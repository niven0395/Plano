import SwiftUI

struct EntertainerCategorySection: View {
    let details: EntertainerDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.entertainmentTypes.isEmpty {
                    CategoryChipsGroup(title: "Entertainment", items: details.entertainmentTypes)
                }

                if !details.entertainmentType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CategoryTextLabel(text: details.entertainmentType, systemImage: "theatermasks")
                }

                if !details.suitableAgeRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CategoryTextLabel(text: details.suitableAgeRange, systemImage: "person.2.fill")
                }

                if details.isInteractive {
                    CategoryBooleanLabel(title: "Interactive performance", systemImage: "hand.raised.fill")
                }
            }
        }
    }
}
