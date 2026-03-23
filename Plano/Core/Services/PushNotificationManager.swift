import Foundation
import UIKit
import UserNotifications
import OSLog

@MainActor
@Observable
final class PushNotificationManager: NSObject {
    private(set) var isRegistered = false
    private(set) var deviceToken: String?
    private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined

    @ObservationIgnored private let messagingService: any MessagingServiceProtocol
    @ObservationIgnored private var currentUserID: UUID?
    @ObservationIgnored var onNotificationTapped: ((UUID) -> Void)?

    init(messagingService: any MessagingServiceProtocol) {
        self.messagingService = messagingService
        super.init()
    }

    func requestPermission() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                permissionStatus = .authorized

                #if !targetEnvironment(simulator)
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                #endif

                AppLogger.app.notice("Push notification permission granted")
            } else {
                permissionStatus = .denied
                AppLogger.app.notice("Push notification permission denied")
            }
        } catch {
            AppLogger.app.error("Push notification permission error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func checkPermissionStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        isRegistered = true

        AppLogger.app.notice("Device token received: \(token.prefix(16), privacy: .public)...")

        // Register with server
        if let userID = currentUserID {
            Task {
                try? await messagingService.registerDeviceToken(token, userID: userID)
            }
        }
    }

    func handleRegistrationError(_ error: Error) {
        isRegistered = false
        AppLogger.app.error("Push registration failed: \(error.localizedDescription, privacy: .public)")
    }

    func setCurrentUser(_ userID: UUID?) {
        let previousUserID = currentUserID
        currentUserID = userID

        if let previousUserID, previousUserID != userID, let token = deviceToken {
            Task {
                try? await messagingService.removeDeviceToken(token, userID: previousUserID)
            }
        }

        if let userID, let token = deviceToken {
            Task {
                try? await messagingService.registerDeviceToken(token, userID: userID)
            }
        }
    }

    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let conversationIDString = userInfo["conversation_id"] as? String,
              let conversationID = UUID(uuidString: conversationIDString) else {
            return
        }

        onNotificationTapped?(conversationID)
    }

    func configureCategoriesAndDelegation() {
        let center = UNUserNotificationCenter.current()

        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: .authenticationRequired,
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )

        let messageCategory = UNNotificationCategory(
            identifier: "NEW_MESSAGE",
            actions: [replyAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([messageCategory])
    }
}
