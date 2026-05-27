import SwiftUI

struct VendorProfileEditView: View {
    let store: VendorProfileEditStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    title: "Your listing",
                    subtitle: "Edit each section to help hosts trust and book you."
                )

                AppSurface {
                    VStack(spacing: 0) {
                        ForEach(Array(store.sectionStatuses.enumerated()), id: \.element.id) { index, status in
                            NavigationLink {
                                VendorProfileEditDestinationView(section: status.section, store: store)
                            } label: {
                                VendorProfileEditRow(
                                    section: status.section,
                                    category: store.draft.category,
                                    isComplete: status.isComplete
                                )
                            }
                            .buttonStyle(.plain)

                            if index < store.sectionStatuses.count - 1 {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                }

                DeleteListingSection(store: store)
                    .padding(.top, 8)
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

// MARK: - Row

private struct VendorProfileEditRow: View {
    let section: VendorProfileEditSection
    let category: VendorCategory
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.toneBackground(section.tone))
                Image(systemName: section.symbolName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.toneColor(section.tone))
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(section.dynamicTitle(for: category))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                Text(section.dynamicSubtitle(for: category))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.toneColor(.sage))
                    .accessibilityLabel("Complete")
            } else {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
            }
        }
        .padding(.vertical, 16)
        .contentShape(.rect)
    }
}

// MARK: - Delete listing (tight destructive hierarchy)

private struct DeleteListingSection: View {
    let store: VendorProfileEditStore
    @Environment(InboxStore.self) private var inboxStore

    @State private var isConfirmingListingDelete = false
    @State private var isDeletingListing = false
    @State private var listingDeletionError: String?

    private var activeBookingCount: Int {
        inboxStore.activeVendorBookingCount
    }

    private var deleteSummaryText: String {
        if isDeletingListing { return "Deleting…" }
        if activeBookingCount > 0 {
            return "Delete listing · cancels \(activeBookingCount) booking\(activeBookingCount == 1 ? "" : "s")"
        }
        return "Delete listing"
    }

    var body: some View {
        Button(role: .destructive) {
            isConfirmingListingDelete = true
        } label: {
            HStack(spacing: 8) {
                if isDeletingListing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.toneColor(.coral))
                }
                Text(deleteSummaryText)
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(AppTheme.toneColor(.coral))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isDeletingListing)
        .hapticFeedback(.warning, trigger: isConfirmingListingDelete) { _, new in new }
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

// MARK: - Section icon / tone mapping

private extension VendorProfileEditSection {
    var symbolName: String {
        switch self {
        case .basicInfo: "person.text.rectangle.fill"
        case .about: "text.alignleft"
        case .categoryDetails: "square.grid.2x2.fill"
        case .pricing: "dollarsign.circle.fill"
        case .services: "checklist"
        case .leadIntake: "questionmark.bubble.fill"
        case .gallery: "photo.stack.fill"
        case .policies: "doc.text.fill"
        case .availability: "calendar"
        case .socialContact: "link"
        case .tagsKeywords: "tag.fill"
        }
    }

    var tone: AccentTone {
        switch self {
        case .basicInfo: .blue
        case .about: .sand
        case .categoryDetails: .blue
        case .pricing: .sage
        case .services: .sage
        case .leadIntake: .gold
        case .gallery: .coral
        case .policies: .sand
        case .availability: .blue
        case .socialContact: .coral
        case .tagsKeywords: .gold
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
