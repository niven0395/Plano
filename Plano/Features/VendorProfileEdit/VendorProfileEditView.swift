import SwiftUI

struct VendorProfileEditView: View {
    let store: VendorProfileEditStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    title: "Business profile",
                    subtitle: "Build this section by section. Hosts should only see confident, useful information."
                )

                LazyVStack(spacing: 14) {
                    ForEach(store.sectionStatuses) { status in
                        NavigationLink {
                            VendorProfileEditDestinationView(section: status.section, store: store)
                        } label: {
                            AppSurface {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(status.section.dynamicTitle(for: store.draft.category))
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.Palette.textPrimary)

                                        Text(status.section.dynamicSubtitle(for: store.draft.category))
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.Palette.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: status.isComplete ? "checkmark.circle.fill" : "circle")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(status.isComplete ? AppTheme.toneColor(.sage) : AppTheme.Palette.subdued)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                DeleteListingSection(store: store)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadIfNeeded()
        }
    }
}

private struct DeleteListingSection: View {
    let store: VendorProfileEditStore
    @Environment(InboxStore.self) private var inboxStore

    @State private var isConfirmingListingDelete = false
    @State private var isDeletingListing = false
    @State private var listingDeletionError: String?

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("Remove listing")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                let activeBookingCount = inboxStore.activeVendorBookingCount
                Text(activeBookingCount > 0
                    ? "Deleting your listing will cancel \(activeBookingCount) active booking\(activeBookingCount == 1 ? "" : "s") and notify each host. Your account stays active as a host."
                    : "Permanently remove your vendor profile, gallery, services, and availability data. Your account stays active as a host."
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)

                Button(role: .destructive) {
                    isConfirmingListingDelete = true
                } label: {
                    HStack {
                        if isDeletingListing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Delete listing")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.toneColor(.coral))
                .disabled(isDeletingListing)
            }
        }
        .confirmationDialog(
            "Delete vendor listing",
            isPresented: $isConfirmingListingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete listing", role: .destructive) {
                Task {
                    isDeletingListing = true
                    let result = await store.deleteVendorListing()
                    isDeletingListing = false

                    if result != nil {
                        await inboxStore.reload()
                    } else {
                        listingDeletionError = "Could not delete your listing. Check your connection and try again."
                    }
                }
            }
        } message: {
            let activeBookingCount = inboxStore.activeVendorBookingCount
            if activeBookingCount > 0 {
                Text("This will cancel \(activeBookingCount) active booking\(activeBookingCount == 1 ? "" : "s") and notify each host. Your vendor profile, gallery, and services will be permanently removed.")
            } else {
                Text("Your vendor profile, gallery, and services will be permanently removed. This action cannot be undone.")
            }
        }
        .alert("Unable to delete", isPresented: .init(
            get: { listingDeletionError != nil },
            set: { if !$0 { listingDeletionError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(listingDeletionError ?? "")
        }
    }
}

// MARK: - Extracted Destination View

private struct VendorProfileEditDestinationView: View {
    let section: VendorProfileEditSection
    let store: VendorProfileEditStore

    var body: some View {
        switch section {
        case .basicInfo:
            BasicInfoEditView(store: store)
        case .about:
            AboutEditView(store: store)
        case .categoryDetails:
            CategoryDetailsEditView(store: store)
        case .pricing:
            PricingEditView(store: store)
        case .services:
            ServicesEditView(store: store)
        case .leadIntake:
            LeadIntakeEditView(store: store)
        case .gallery:
            GalleryEditView(store: store)
        case .policies:
            PoliciesEditView(store: store)
        case .availability:
            AvailabilityEditView(store: store)
        case .socialContact:
            SocialLinksEditView(store: store)
        case .tagsKeywords:
            TagsEditView(store: store)
        }
    }
}
