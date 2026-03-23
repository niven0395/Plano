import SwiftUI

struct PhotographyCategorySection: View {
    let details: PhotoVideoDetails

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                if !details.deliverables.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deliverables")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 110), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(details.deliverables, id: \.self) { deliverable in
                                FilterChip(title: deliverable, isSelected: false)
                            }
                        }
                    }
                }

                if !details.turnaroundNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(details.turnaroundNote, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                if details.secondShooterAvailable {
                    Label("Second shooter available", systemImage: "person.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.blue))
                }

                if details.droneAvailable {
                    Label("Drone available", systemImage: "airplane")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.blue))
                }
            }
        }
    }
}
