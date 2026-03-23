import SwiftUI

struct ProfileVendorLink: View {
    let vendorDisplayName: String?
    let vendorProfileEditStore: VendorProfileEditStore
    let currentUserID: UUID?

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vendor profile")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.subdued)

                    if let vendorDisplayName {
                        Text(vendorDisplayName)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    }
                }

                HStack(spacing: 10) {
                    NavigationLink {
                        VendorProfileEditView(store: vendorProfileEditStore)
                    } label: {
                        Label("Edit profile", systemImage: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(AppTheme.Palette.chipFill, in: .capsule)
                            .overlay {
                                Capsule().stroke(AppTheme.Palette.border, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    if let currentUserID {
                        NavigationLink(value: DiscoveryRoute.vendorProfile(currentUserID)) {
                            Label("View listing", systemImage: "eye")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(AppTheme.Palette.chipFill, in: .capsule)
                                .overlay {
                                    Capsule().stroke(AppTheme.Palette.border, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
