import SwiftUI

struct ProfileAuthActions: View {
    let isAnonymous: Bool
    let isVendorAuthenticated: Bool
    let supportsAppleSignIn: Bool
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
            Button("List your business") {
                authStore.startVendorSetup()
            }
            .buttonStyle(PrimaryActionButtonStyle())

            if supportsAppleSignIn {
                Button("Sign in with Apple") {
                    authStore.presentHostUpgrade()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            Button("Sign in with email") {
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
