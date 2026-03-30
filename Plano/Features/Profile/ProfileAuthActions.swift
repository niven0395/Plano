import SwiftUI

struct ProfileAuthActions: View {
    let isAnonymous: Bool
    let isVendorAuthenticated: Bool
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        if isAnonymous {
            anonymousActions
        } else if !isVendorAuthenticated {
            vendorPrompt
        }
    }

    private var anonymousActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Create an account") {
                authStore.presentCreateAccount()
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button("Sign in") {
                authStore.presentEmailAuth()
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private var vendorPrompt: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Also a vendor?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Button("List your business") {
                    authStore.startVendorSetup()
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }
}
