import SwiftUI

struct SocialLinksEditView: View {
    let store: VendorProfileEditStore

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Phone", text: $store.draft.phone)
                            .keyboardType(.phonePad)

                        Divider()

                        TextField("Website", text: $store.draft.website)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()

                        Divider()

                        TextField("Instagram handle", text: $store.draft.instagramHandle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Divider()

                        TextField("TikTok handle", text: $store.draft.tiktokHandle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Button(store.loadingState.isLoading ? "Saving..." : "Save contact links") {
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
        .navigationTitle("Social & Contact")
        .navigationBarTitleDisplayMode(.inline)
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Contact links saved") {
            store.lastSaveOutcome = .idle
        }
    }
}
