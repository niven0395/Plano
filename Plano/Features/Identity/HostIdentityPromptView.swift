import SwiftUI

struct HostIdentityPromptView: View {
    let store: HostIdentityPromptStore

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Who should the vendor talk to?",
                        subtitle: "This is not an account. It just tells the vendor who is reaching out."
                    )

                    AppSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("First name", text: $store.firstName)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.next)

                            Divider()

                            TextField("Last name (optional)", text: $store.lastName)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.next)

                            Divider()

                            TextField("Phone (optional)", text: $store.phone)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)

                            Divider()

                            TextField("Email (optional)", text: $store.email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.emailAddress)
                        }
                    }

                    if let message = store.loadingState.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.toneColor(.coral))
                    }

                    Text("Your name is only used so the vendor knows who they’re speaking with.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.subdued)

                    Button(store.loadingState.isLoading ? "Saving..." : "Continue") {
                        Task {
                            await store.submit()
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!store.isValid || store.loadingState.isLoading)
                    .hapticFeedback(.success, trigger: store.loadingState) { old, new in
                        old.isLoading && !new.isLoading && new.errorMessage == nil
                    }
                }
                .padding(AppTheme.screenPadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AppBackdrop())
            .navigationTitle("Before you message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now", action: store.dismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
