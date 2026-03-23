import PhotosUI
import SwiftUI

struct BasicInfoEditView: View {
    let store: VendorProfileEditStore
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                displayPictureCard

                AppSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Business name", text: $store.draft.businessName)
                            .textInputAutocapitalization(.words)

                        Divider()

                        Menu {
                            Picker("Category", selection: $store.draft.category) {
                                ForEach(VendorCategory.allCases) { category in
                                    Label(category.singularTitle, systemImage: category.symbolName)
                                        .tag(category)
                                }
                            }
                        } label: {
                            MenuDropdownRow(
                                title: store.draft.category.singularTitle,
                                icon: store.draft.category.symbolName
                            )
                        }

                        Divider()

                        Menu {
                            Picker("City", selection: Binding(
                                get: { GTACity(rawValue: store.draft.city) ?? .toronto },
                                set: { store.draft.city = $0.rawValue }
                            )) {
                                ForEach(GTACity.allCases) { city in
                                    Text(city.title).tag(city)
                                }
                            }
                        } label: {
                            MenuDropdownRow(title: (GTACity(rawValue: store.draft.city) ?? .toronto).title)
                        }
                    }
                }

                Button(store.loadingState.isLoading ? "Saving..." : "Save basic info") {
                    Task {
                        await store.save()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(store.draft.businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.loadingState.isLoading)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Basic Info")
        .navigationBarTitleDisplayMode(.inline)
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Basic info saved") {
            store.lastSaveOutcome = .idle
        }
        .onChange(of: store.draft.category) { _, newCategory in
            store.resetLeadIntakeQuestionsToTemplate()
            store.draft.categoryDetails = .empty(for: newCategory)
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            guard let newPhoto else { return }
            Task {
                if let data = try? await newPhoto.loadTransferable(type: Data.self) {
                    await store.uploadProfileImage(data: data)
                }
                selectedPhoto = nil
            }
        }
    }

    private var displayPictureCard: some View {
        AppSurface {
            VStack(spacing: 16) {
                if store.draft.profileImagePath != nil {
                    PlanoImage(
                        storagePath: store.draft.profileImagePath,
                        size: .thumbnail,
                        cornerRadius: 50,
                        contentMode: .fill
                    )
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppTheme.toneBackground(store.draft.category.accentTone))
                        .frame(width: 100, height: 100)
                        .overlay {
                            Image(systemName: store.draft.category.symbolName)
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.toneColor(store.draft.category.accentTone))
                        }
                }

                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {
                        Text(store.draft.profileImagePath != nil ? "Change photo" : "Add photo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }

                    if store.draft.profileImagePath != nil {
                        Button("Remove") {
                            Task {
                                await store.removeProfileImage()
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.coral))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
