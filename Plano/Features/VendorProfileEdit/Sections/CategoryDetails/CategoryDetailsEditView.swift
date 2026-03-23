import SwiftUI

struct CategoryDetailsEditView: View {
    let store: VendorProfileEditStore

    var body: some View {
        Group {
            switch store.draft.category {
            case .photographer:
                PhotographyDetailsEditView(store: store)
            default:
                comingSoonView
            }
        }
        .navigationTitle(store.draft.categoryDetails?.sectionTitle ?? categoryDetailsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var categoryDetailsTitle: String {
        CategoryDetails.empty(for: store.draft.category).sectionTitle
    }

    private var comingSoonView: some View {
        ScrollView {
            VStack(spacing: 20) {
                AppSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category-specific details for \(store.draft.category.title.lowercased()) are coming soon.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
    }
}
