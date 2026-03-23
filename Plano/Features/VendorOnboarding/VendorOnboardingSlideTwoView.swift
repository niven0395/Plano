import SwiftUI

struct VendorOnboardingSlideTwoView: View {
    let store: VendorOnboardingStore

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: "Tell hosts about your business",
                subtitle: "Help hosts understand what makes you different."
            )

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bio")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(bioPrompt(for: store.selectedCategory))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    TextEditor(text: $store.bio)
                        .frame(minHeight: 140)

                    Text("\(store.bio.count)/500")
                        .font(.caption)
                        .foregroundStyle(store.bio.count > 500 ? AppTheme.toneColor(.coral) : AppTheme.Palette.subdued)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            AppSurface(style: .highlighted) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your tagline")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("One sentence that captures your style. This appears in search results.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    TextField("A short, memorable line", text: $store.styleSummary)

                    Text("\(store.styleSummary.count)/120")
                        .font(.caption)
                        .foregroundStyle(store.styleSummary.count > 120 ? AppTheme.toneColor(.coral) : AppTheme.Palette.subdued)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Examples")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)

                        ForEach(exampleTaglines(for: store.selectedCategory), id: \.self) { tagline in
                            Text(tagline)
                                .font(.caption)
                                .italic()
                                .foregroundStyle(AppTheme.Palette.subdued)
                        }
                    }
                }
            }

            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Service area")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Where can hosts book you? Include cities, regions, or \"Willing to travel\".")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    TextField("e.g. Toronto + GTA", text: $store.serviceArea)
                        .textInputAutocapitalization(.words)
                }
            }
        }
    }

    private func bioPrompt(for category: VendorCategory) -> String {
        switch category {
        case .photographer:
            "Tell hosts what makes your photography style distinctive. What moments do you focus on?"
        case .decorator, .florist:
            "Describe your design approach. What atmosphere do you create for events?"
        case .caterer:
            "What kind of food experience do you bring? Mention cuisine styles and any specialties."
        case .dj:
            "What energy do you bring to events? Describe your sound and how you read a crowd."
        case .eventSpace:
            "What makes your space special? Mention capacity, vibe, and what's included."
        case .baker:
            "What's your signature style? Describe flavors, designs, or custom work you love."
        case .bartender:
            "Describe your bar service and cocktail style. What makes your setup stand out?"
        default:
            "Tell hosts what you do best. What should they expect when they book you?"
        }
    }

    private func exampleTaglines(for category: VendorCategory) -> [String] {
        switch category {
        case .photographer:
            [
                "Candid moments, cinematic light.",
                "Documentary-style coverage with an editorial eye.",
            ]
        case .decorator, .florist:
            [
                "Lush, textured designs for intimate gatherings.",
                "Modern minimalism meets natural beauty.",
            ]
        case .caterer:
            [
                "Farm-to-table menus tailored to your guest list.",
                "Bold flavours, beautiful platters, zero stress.",
            ]
        case .dj:
            [
                "Smooth transitions, packed dance floors.",
                "Open-format sets that read the room.",
            ]
        case .eventSpace:
            [
                "An industrial canvas for unforgettable evenings.",
                "Sunlit spaces with skyline views.",
            ]
        default:
            [
                "Trusted by hosts across the city.",
                "Personal service, professional results.",
            ]
        }
    }
}
