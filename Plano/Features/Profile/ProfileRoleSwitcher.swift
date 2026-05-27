import SwiftUI

struct ProfileRoleSwitcher: View {
    let availableRoles: [UserRole]
    @Binding var currentRole: UserRole

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active role")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.subdued)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(spacing: 6) {
                ForEach(availableRoles) { role in
                    Button {
                        currentRole = role
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: symbolName(for: role))
                                .font(.footnote.weight(.semibold))
                                .accessibilityHidden(true)
                            Text(role.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(currentRole == role
                                         ? AppTheme.Palette.accentForeground
                                         : AppTheme.Palette.textPrimary)
                        .background(
                            currentRole == role
                                ? AnyShapeStyle(AppTheme.Palette.accent)
                                : AnyShapeStyle(Color.clear),
                            in: .rect(cornerRadius: 10, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(currentRole == role ? [.isSelected] : [])
                }
            }
            .padding(4)
            .background(AppTheme.Palette.chipFill, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.Palette.border, lineWidth: 1)
            }
            .hapticFeedback(.selection, trigger: currentRole)
        }
    }

    private func symbolName(for role: UserRole) -> String {
        role == .vendor ? "storefront.fill" : "person.fill"
    }
}
