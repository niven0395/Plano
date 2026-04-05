import SwiftUI

struct PhotographyCategorySection: View {
    let details: PhotoVideoDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 10) {
                if !details.deliverables.isEmpty {
                    CategoryChipsGroup(title: "Deliverables", items: details.deliverables)
                }

                if !details.turnaroundNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CategoryTextLabel(text: details.turnaroundNote, systemImage: "clock")
                }

                if details.secondShooterAvailable {
                    CategoryBooleanLabel(title: "Second shooter available", systemImage: "person.2.fill")
                }

                if details.droneAvailable {
                    CategoryBooleanLabel(title: "Drone available", systemImage: "airplane")
                }
            }
        }
    }
}
