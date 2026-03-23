import PhotosUI
import SwiftUI

struct VendorOnboardingSlideOneView: View {
    let store: VendorOnboardingStore
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(
                title: "Business essentials",
                subtitle: "This is the only required step. Everything else can be added later."
            )

            profileImageCard

            AppSurface {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Business name", text: $store.businessName)
                        .textInputAutocapitalization(.words)

                    Divider()

                    TextField("Business email", text: $store.businessEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Divider()

                    Text("Category")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)

                    Menu {
                        Picker("Category", selection: $store.selectedCategory) {
                            ForEach(VendorCategory.allCases) { category in
                                Label(category.singularTitle, systemImage: category.symbolName)
                                    .tag(category)
                            }
                        }
                    } label: {
                        MenuDropdownRow(
                            title: store.selectedCategory.singularTitle,
                            icon: store.selectedCategory.symbolName
                        )
                    }

                    Divider()

                    Text("City")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)

                    Menu {
                        Picker("City", selection: $store.city) {
                            ForEach(GTACity.allCases) { city in
                                Text(city.title).tag(city)
                            }
                        }
                    } label: {
                        MenuDropdownRow(title: store.city.title)
                    }
                }
            }
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

    private var profileImageCard: some View {
        AppSurface {
            VStack(spacing: 16) {
                if store.profileImagePath != nil {
                    PlanoImage(
                        storagePath: store.profileImagePath,
                        size: .thumbnail,
                        cornerRadius: 50,
                        contentMode: .fill
                    )
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppTheme.toneBackground(store.selectedCategory.accentTone))
                        .frame(width: 100, height: 100)
                        .overlay {
                            Image(systemName: store.selectedCategory.symbolName)
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.toneColor(store.selectedCategory.accentTone))
                        }
                }

                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {
                        Text(store.profileImagePath != nil ? "Change logo" : "Add logo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }

                    if store.profileImagePath != nil {
                        Button("Remove") {
                            store.removeProfileImage()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.coral))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                }

                Text("Optional")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.subdued)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
