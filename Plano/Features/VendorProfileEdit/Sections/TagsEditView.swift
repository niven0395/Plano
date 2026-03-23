import SwiftUI

struct TagsEditView: View {
    let store: VendorProfileEditStore
    @State private var tagsText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keywords")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)

                        TextField("princess party, candlelight dinner, luxe florals", text: $tagsText, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                    }
                }

                Button(store.loadingState.isLoading ? "Saving..." : "Save tags") {
                    store.draft.tags = tagsText
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    Task {
                        await store.save()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(store.loadingState.isLoading)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Tags & Keywords")
        .navigationBarTitleDisplayMode(.inline)
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Tags saved") {
            store.lastSaveOutcome = .idle
        }
        .onAppear {
            tagsText = store.draft.tags.joined(separator: ", ")
        }
    }
}
