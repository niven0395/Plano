import SwiftUI

struct ProfileAccountSection: View {
    let isAuthenticated: Bool
    let isVendorAuthenticated: Bool
    let totalActiveBookings: Int
    @Environment(AuthStore.self) private var authStore

    @State private var isConfirmingSignOut = false
    @State private var isSigningOut = false
    @State private var isConfirmingAccountDelete = false
    @State private var isDeletingAccount = false
    @State private var accountDeletionError: String?

    var body: some View {
        if isAuthenticated {
            signOutCard
            deleteAccountCard
        } else {
            guestFooter
        }
    }

    private var signOutCard: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Button(isSigningOut ? "Signing out..." : "Sign out") {
                    isConfirmingSignOut = true
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(isSigningOut)
            }
        }
        .confirmationDialog(
            "Sign out",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                isSigningOut = true
                Task {
                    await authStore.signOut()
                    isSigningOut = false
                }
            }
        } message: {
            Text("You'll need to sign in again to access your account.")
        }
        .hapticFeedback(.warning, trigger: isConfirmingSignOut) { _, new in new }
    }

    private var guestFooter: some View {
        Text("Guest data stays on this device.")
            .font(.footnote)
            .foregroundStyle(AppTheme.Palette.subdued)
    }

    private var deleteAccountCard: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text(totalActiveBookings > 0
                    ? "Deleting your account will cancel \(totalActiveBookings) active booking\(totalActiveBookings == 1 ? "" : "s") and remove all data."
                    : "Permanently delete your account and all associated data."
                )
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)

                Button(role: .destructive) {
                    isConfirmingAccountDelete = true
                } label: {
                    HStack {
                        if isDeletingAccount {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Delete account")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.toneColor(.coral))
                .disabled(isDeletingAccount)
                .hapticFeedback(.warning, trigger: isConfirmingAccountDelete) { _, new in new }
            }
        }
        .confirmationDialog(
            "Delete account",
            isPresented: $isConfirmingAccountDelete,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    let result = await authStore.deleteAccount()
                    isDeletingAccount = false

                    if result == nil {
                        accountDeletionError = "Could not delete your account. Check your connection and try again."
                    }
                }
            }
        } message: {
            if totalActiveBookings > 0 {
                Text("This will cancel \(totalActiveBookings) active booking\(totalActiveBookings == 1 ? "" : "s") and notify each counterparty. Your account and all associated data will be permanently removed.")
            } else {
                Text("Your account, events, conversations, bookings\(isVendorAuthenticated ? ", and vendor listing" : "") will be permanently removed. This action cannot be undone.")
            }
        }
        .alert("Unable to delete account", isPresented: .init(
            get: { accountDeletionError != nil },
            set: { if !$0 { accountDeletionError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(accountDeletionError ?? "")
        }
    }
}
