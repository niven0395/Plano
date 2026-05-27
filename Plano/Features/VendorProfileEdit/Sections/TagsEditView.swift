import SwiftUI

struct TagsEditView: View {
    let store: VendorProfileEditStore
    @State private var tagsText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keywords")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    TextField("princess party, candlelight dinner, luxe florals", text: $tagsText, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                        .planoFormField(systemImage: "tag.fill")
                }

                Text("Separate keywords with commas. They expand search reach without appearing on your profile.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Palette.subdued)
                    .padding(.top, 4)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Tags & Keywords")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VendorProfileEditSaveBar(store: store, buttonLabel: "Save tags")
        }
        .onChange(of: tagsText) { _, new in
            store.draft.tags = new
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Tags saved") {
            store.lastSaveOutcome = .idle
        }
        .onAppear {
            tagsText = store.draft.tags.joined(separator: ", ")
        }
    }
}
