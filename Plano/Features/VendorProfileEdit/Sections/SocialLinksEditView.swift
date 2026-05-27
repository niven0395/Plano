import SwiftUI

struct SocialLinksEditView: View {
    let store: VendorProfileEditStore

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Phone number", text: $store.draft.phone)
                    .keyboardType(.phonePad)
                    .planoFormField(systemImage: "phone.fill")

                TextField("Website", text: $store.draft.website)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .planoFormField(systemImage: "globe")

                TextField("Instagram handle", text: $store.draft.instagramHandle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .planoFormField(systemImage: "camera.fill")

                TextField("TikTok handle", text: $store.draft.tiktokHandle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .planoFormField(systemImage: "music.note")

                Text("Hosts see these on your profile and in search results. Leave blank to hide a field.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Palette.subdued)
                    .padding(.top, 4)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Social & Contact")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VendorProfileEditSaveBar(store: store, buttonLabel: "Save contact links")
        }
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Contact links saved") {
            store.lastSaveOutcome = .idle
        }
    }
}
