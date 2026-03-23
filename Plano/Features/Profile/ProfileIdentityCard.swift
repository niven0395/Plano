import SwiftUI

struct ProfileIdentityCard: View {
    let displayName: String
    var emailAddress: String?
    var contactPhone: String?
    var contactEmail: String?
    var isGuest: Bool = false

    var body: some View {
        AppSurface(style: .highlighted) {
            VStack(alignment: .leading, spacing: 14) {
                Text(displayName)
                    .font(.system(size: 28, weight: .regular))
                    .tracking(-0.8)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                if let email = emailAddress, !email.isEmpty {
                    Label(email, systemImage: "envelope.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)
                }

                if contactPhone != nil || contactEmail != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if let phone = contactPhone, !phone.isEmpty {
                            Label(phone, systemImage: "phone.fill")
                        }

                        if let email = contactEmail, !email.isEmpty {
                            Label(email, systemImage: "envelope.fill")
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                }

                if isGuest {
                    Text("Browsing as a guest")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.subdued)
                }
            }
        }
    }
}
