import SwiftUI

struct AboutEditView: View {
    let store: VendorProfileEditStore

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSurface {
                    VStack(alignment: .leading, spacing: 22) {
                        bioSection
                        Divider()
                        taglineSection
                        Divider()
                        serviceAreaSection
                    }
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VendorProfileEditSaveBar(store: store, buttonLabel: "Save about section")
        }
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "About section saved") {
            store.lastSaveOutcome = .idle
        }
    }

    // MARK: - Sections

    private var bioSection: some View {
        @Bindable var store = store

        let bioCount = store.draft.bio.count
        return VStack(alignment: .leading, spacing: 10) {
            Text("Bio")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text(bioPrompt(for: store.draft.category))
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            TextEditor(text: $store.draft.bio)
                .frame(minHeight: 140)
                .planoFormField()

            Text("\(bioCount)/500")
                .font(.caption)
                .foregroundStyle(bioCount > 500 ? AppTheme.toneColor(.coral) : AppTheme.Palette.subdued)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var taglineSection: some View {
        @Bindable var store = store

        let taglineCount = store.draft.styleSummary.count
        return VStack(alignment: .leading, spacing: 10) {
            Text("Your tagline")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text("One sentence that captures your style. This appears in search results.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            TextField("A short, memorable line", text: $store.draft.styleSummary)
                .planoFormField(systemImage: "quote.opening")

            Text("\(taglineCount)/120")
                .font(.caption)
                .foregroundStyle(taglineCount > 120 ? AppTheme.toneColor(.coral) : AppTheme.Palette.subdued)
                .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(alignment: .leading, spacing: 6) {
                Text("Examples")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                    .textCase(.uppercase)
                    .tracking(0.4)

                ForEach(exampleTaglines(for: store.draft.category), id: \.self) { tagline in
                    Text(tagline)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
            }
            .padding(.top, 4)
        }
    }

    private var serviceAreaSection: some View {
        @Bindable var store = store

        return VStack(alignment: .leading, spacing: 10) {
            Text("Service area")
                .font(.headline)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text("Where can hosts book you? Include cities, regions, or \"Willing to travel\".")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            TextField("e.g. Toronto + GTA", text: $store.draft.serviceArea)
                .textInputAutocapitalization(.words)
                .planoFormField(systemImage: "mappin.and.ellipse")
        }
    }

    // MARK: - Copy

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
