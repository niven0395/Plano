import SwiftUI

struct VendorAllWorkView: View {
    @Environment(VendorDashboardStore.self) private var store
    @Environment(InboxStore.self) private var inboxStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "All confirmed work")

                if store.confirmedLeads.isEmpty {
                    EmptyStateCard(
                        symbolName: "checkmark.seal",
                        title: "No confirmed bookings",
                        message: "Bookings with confirmed deposits will appear here."
                    )
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(store.confirmedLeads) { lead in
                            NavigationLink(value: DiscoveryRoute.vendorLead(lead)) {
                                VendorAllWorkRow(request: lead)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("All work")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct VendorAllWorkRow: View {
    let request: BookingRequestSummary

    var body: some View {
        AppSurface {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(AppTheme.toneColor(request.stage.tone))
                    .frame(width: 8, height: 8)
                    .padding(.top, 7)

                VStack(alignment: .leading, spacing: 6) {
                    Text(request.counterpartName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("\(request.title) \u{00B7} \(request.dateLabel)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(request.counterpartName), \(request.title), \(request.dateLabel)")
    }
}
