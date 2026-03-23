import SwiftUI
import UserNotifications

struct ProfileNotificationsSection: View {
    @Environment(PushNotificationManager.self) private var pushNotificationManager
    @Environment(ProfilePreferences.self) private var preferences
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch pushNotificationManager.permissionStatus {
        case .notDetermined:
            notDeterminedCard
        case .denied:
            deniedCard
        case .authorized, .provisional, .ephemeral:
            categoryToggles
        @unknown default:
            categoryToggles
        }
    }

    private var notDeterminedCard: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stay updated on messages, bookings, and event reminders.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Button("Turn on notifications") {
                    Task {
                        await pushNotificationManager.requestPermission()
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }

    private var deniedCard: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Notifications are turned off. Enable them in Settings to receive messages and booking updates.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }

    private var categoryToggles: some View {
        AppSurface {
            @Bindable var preferences = preferences
            VStack(spacing: 0) {
                toggleRow("Messages", isOn: $preferences.notifyMessages)
                Divider().padding(.horizontal, -22)
                toggleRow("Booking updates", isOn: $preferences.notifyBookings)
                Divider().padding(.horizontal, -22)
                toggleRow("Reminders", isOn: $preferences.notifyReminders)
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.subheadline)
            .foregroundStyle(AppTheme.Palette.textPrimary)
            .tint(AppTheme.Palette.accent)
            .padding(.vertical, 6)
    }
}
