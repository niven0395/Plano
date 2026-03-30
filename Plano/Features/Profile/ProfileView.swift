import SwiftUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(SessionStore.self) private var session
    @Environment(VendorProfileEditStore.self) private var vendorProfileEditStore
    @Environment(InboxStore.self) private var inboxStore
    @Environment(PushNotificationManager.self) private var pushNotificationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                identityCard

                if session.isAuthenticated, session.availableRoles.count > 1 {
                    ProfileRoleSwitcher(
                        availableRoles: session.availableRoles,
                        currentRole: Bindable(session).currentRole
                    )
                }

                if session.currentRole == .vendor {
                    ProfileVendorLink(
                        vendorDisplayName: session.authenticatedProfile?.vendorDisplayName,
                        vendorProfileEditStore: vendorProfileEditStore,
                        currentUserID: session.authenticatedProfile?.userID
                    )
                }

                ProfileAuthActions(
                    isAnonymous: session.isAnonymous,
                    isVendorAuthenticated: session.isVendorAuthenticated
                )

                if session.isAuthenticated {
                    SectionHeader(title: "Notifications")
                    ProfileNotificationsSection()
                }

                if !session.isAnonymous {
                    SectionHeader(title: "Preferences")
                    ProfilePreferencesSection()
                }

                SectionHeader(title: "Support")
                ProfileSupportSection()

                ProfileAccountSection(
                    isAuthenticated: session.isAuthenticated,
                    isVendorAuthenticated: session.isVendorAuthenticated,
                    totalActiveBookings: inboxStore.activeHostBookingCount + inboxStore.activeVendorBookingCount
                )
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await pushNotificationManager.checkPermissionStatus()
        }
    }

    private var identityCard: ProfileIdentityCard {
        if session.isAnonymous {
            ProfileIdentityCard(
                displayName: session.currentDisplayName,
                contactPhone: session.anonymousSession?.contactPhone,
                contactEmail: session.anonymousSession?.contactEmail,
                isGuest: true
            )
        } else {
            ProfileIdentityCard(
                displayName: session.currentDisplayName,
                emailAddress: session.authenticatedProfile?.emailAddress
            )
        }
    }
}
