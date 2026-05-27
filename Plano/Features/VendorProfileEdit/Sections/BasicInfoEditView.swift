import PhotosUI
import SwiftUI

struct BasicInfoEditView: View {
    let store: VendorProfileEditStore
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedListingPhoto: PhotosPickerItem?

    private var isSaveEnabled: Bool {
        !store.draft.businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                identityHeroCard
                listingImageCard

                AppSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Business name")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                                .textCase(.uppercase)
                                .tracking(0.4)
                            TextField("Your business", text: $store.draft.businessName)
                                .textInputAutocapitalization(.words)
                                .planoFormField(systemImage: "building.2.fill")
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                                .textCase(.uppercase)
                                .tracking(0.4)
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
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("City")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.subdued)
                                .textCase(.uppercase)
                                .tracking(0.4)
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
                                MenuDropdownRow(
                                    title: (GTACity(rawValue: store.draft.city) ?? .toronto).title,
                                    icon: "mappin.and.ellipse"
                                )
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Basic Info")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VendorProfileEditSaveBar(
                store: store,
                buttonLabel: "Save basic info",
                isSaveEnabled: isSaveEnabled
            )
        }
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Basic info saved") {
            store.lastSaveOutcome = .idle
        }
        .onChange(of: store.draft.category) { _, newCategory in
            store.draft.leadIntakeQuestions = []
            store.draft.collectsGuestCount = newCategory.defaultCollectsGuestCount
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
        .onChange(of: selectedListingPhoto) { _, newPhoto in
            guard let newPhoto else { return }
            Task {
                if let data = try? await newPhoto.loadTransferable(type: Data.self) {
                    await store.uploadListingImage(data: data)
                }
                selectedListingPhoto = nil
            }
        }
    }

    // MARK: - Identity hero (photo + name preview + category chip)

    private var identityHeroCard: some View {
        @Bindable var store = store

        return AppSurface(style: .highlighted) {
            HStack(alignment: .top, spacing: 16) {
                profileAvatar

                VStack(alignment: .leading, spacing: 6) {
                    Text(previewName)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .tracking(-0.4)
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 5) {
                        Image(systemName: store.draft.category.symbolName)
                            .font(.caption2.weight(.semibold))
                        Text(store.draft.category.singularTitle)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.toneColor(store.draft.category.accentTone))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(AppTheme.toneBackground(store.draft.category.accentTone), in: Capsule())

                    HStack(spacing: 10) {
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images
                        ) {
                            Text(store.draft.profileImagePath != nil ? "Change photo" : "Add photo")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.accent)
                        }

                        if store.draft.profileImagePath != nil {
                            Button("Remove") {
                                Task {
                                    await store.removeProfileImage()
                                }
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.toneColor(.coral))
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var previewName: String {
        let trimmed = store.draft.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your business" : trimmed
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if store.draft.profileImagePath != nil {
            PlanoImage(
                storagePath: store.draft.profileImagePath,
                size: .thumbnail,
                cornerRadius: 40,
                contentMode: .fill
            )
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(AppTheme.Palette.border, lineWidth: 1)
            }
        } else {
            Circle()
                .fill(AppTheme.toneBackground(store.draft.category.accentTone))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: store.draft.category.symbolName)
                        .font(.system(size: 30))
                        .foregroundStyle(AppTheme.toneColor(store.draft.category.accentTone))
                }
                .overlay {
                    Circle().stroke(AppTheme.toneColor(store.draft.category.accentTone).opacity(0.2), lineWidth: 1)
                }
        }
    }

    // MARK: - Listing image

    private var listingImageCard: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                Text("Listing image")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("This appears on search and browse cards. If not set, your profile photo is used.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Group {
                    if let listingPath = store.draft.listingImagePath, !listingPath.isEmpty {
                        PlanoImage(
                            storagePath: listingPath,
                            size: .standard,
                            cornerRadius: AppTheme.cardCornerRadius,
                            contentMode: .fill
                        )
                    } else if let profilePath = store.draft.profileImagePath, !profilePath.isEmpty {
                        PlanoImage(
                            storagePath: profilePath,
                            size: .standard,
                            cornerRadius: AppTheme.cardCornerRadius,
                            contentMode: .fill
                        )
                        .overlay(alignment: .bottom) {
                            Text("Using profile photo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.5), in: Capsule())
                                .padding(.bottom, 10)
                        }
                        .opacity(0.7)
                    } else {
                        EditorialArtworkPanel(
                            tone: store.draft.category.accentTone,
                            symbolName: store.draft.category.symbolName,
                            height: 160
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))

                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $selectedListingPhoto,
                        matching: .images
                    ) {
                        Text(store.draft.listingImagePath != nil ? "Change listing image" : "Add listing image")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.accent)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }

                    if store.draft.listingImagePath != nil {
                        Button("Remove") {
                            Task {
                                await store.removeListingImage()
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.toneColor(.coral))
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
    }
}
