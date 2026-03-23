import SwiftUI

struct ProfileRoleSwitcher: View {
    let availableRoles: [UserRole]
    @Binding var currentRole: UserRole

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Active role")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                HStack(spacing: 10) {
                    ForEach(availableRoles) { role in
                        Button {
                            currentRole = role
                        } label: {
                            FilterChip(
                                title: role.title,
                                isSelected: currentRole == role
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .hapticFeedback(.selection, trigger: currentRole)
                }
            }
        }
    }
}
