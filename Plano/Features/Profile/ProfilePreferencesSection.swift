import SwiftUI

struct ProfilePreferencesSection: View {
    @Environment(ProfilePreferences.self) private var preferences

    var body: some View {
        AppSurface {
            @Bindable var preferences = preferences
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Haptic feedback", isOn: $preferences.hapticsEnabled)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .tint(AppTheme.Palette.accent)

                Text("Vibrations for buttons, toggles, and confirmations.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }
        }
    }
}
