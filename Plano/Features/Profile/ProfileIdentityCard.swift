import SwiftUI

struct ProfileIdentityCard: View {
    let displayName: String
    var emailAddress: String?
    var contactPhone: String?
    var contactEmail: String?
    var isGuest: Bool = false
    var role: UserRole? = nil

    private var monogram: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let initials = trimmed.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
        return initials.isEmpty ? "?" : initials.uppercased()
    }

    private var avatarTone: AccentTone {
        if isGuest { return .sand }
        return role == .vendor ? .sage : .blue
    }

    private var roleChipLabel: String {
        if isGuest { return "Guest" }
        return role == .vendor ? "Vendor" : "Host"
    }

    private var roleChipSymbol: String {
        if isGuest { return "eye" }
        return role == .vendor ? "storefront.fill" : "person.fill"
    }

    var body: some View {
        AppSurface(style: .highlighted) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.toneBackground(avatarTone))
                    Text(monogram)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.toneColor(avatarTone))
                }
                .frame(width: 56, height: 56)
                .overlay {
                    Circle()
                        .stroke(AppTheme.toneColor(avatarTone).opacity(0.2), lineWidth: 1)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(displayName)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .tracking(-0.6)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .truncationMode(.tail)

                        Spacer(minLength: 4)

                        roleChip
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if let email = emailAddress, !email.isEmpty {
                            Label(email, systemImage: "envelope.fill")
                        }

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

                Spacer(minLength: 0)
            }
        }
    }

    private var roleChip: some View {
        HStack(spacing: 5) {
            Image(systemName: roleChipSymbol)
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)
            Text(roleChipLabel)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppTheme.toneColor(avatarTone))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(AppTheme.toneBackground(avatarTone), in: Capsule())
        .overlay {
            Capsule().stroke(AppTheme.toneColor(avatarTone).opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(roleChipLabel) account")
    }
}
