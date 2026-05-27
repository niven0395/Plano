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
            accountActionsGroup
        } else {
            guestFooter
        }
    }

    private var accountActionsGroup: some View {
        VStack(spacing: 10) {
            Button {
                isConfirmingSignOut = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                    Text(isSigningOut ? "Signing out…" : "Sign out")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Palette.chipFill, in: Capsule())
                .overlay {
                    Capsule().stroke(AppTheme.Palette.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(isSigningOut)
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

            Button(role: .destructive) {
                isConfirmingAccountDelete = true
            } label: {
                HStack(spacing: 8) {
                    if isDeletingAccount {
                        ProgressView().controlSize(.small).tint(AppTheme.toneColor(.coral))
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
            .disabled(isDeletingAccount)
            .hapticFeedback(.warning, trigger: isConfirmingAccountDelete) { _, new in new }
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

    private var guestFooter: some View {
        Text("Guest data stays on this device.")
            .font(.footnote)
            .foregroundStyle(AppTheme.Palette.subdued)
            .frame(maxWidth: .infinity)
    }

    private var deleteSummaryText: String {
        if isDeletingAccount { return "Deleting…" }
        if totalActiveBookings > 0 {
            return "Delete account · cancels \(totalActiveBookings) booking\(totalActiveBookings == 1 ? "" : "s")"
        }
        return "Delete account"
    }
}
