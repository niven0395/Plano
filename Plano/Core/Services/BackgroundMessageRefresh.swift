import BackgroundTasks
import Foundation
import OSLog

enum BackgroundMessageRefresh {
    static let taskIdentifier = "com.plano.message-refresh"

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleRefresh(refreshTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.app.notice("Background message refresh scheduled")
        } catch {
            AppLogger.app.error("Failed to schedule background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func handleRefresh(_ task: BGAppRefreshTask) {
        // Schedule the next refresh before starting work
        schedule()

        let refreshOperation = Task {
            // The actual catch-up sync is performed by InboxStore.catchUpAfterReconnect()
            // when the app returns to the foreground. This background task ensures the
            // system wakes us periodically so we can at least update badges and prepare
            // cached data.
            AppLogger.app.notice("Background message refresh executing")
        }

        task.expirationHandler = {
            refreshOperation.cancel()
        }

        Task {
            await refreshOperation.value
            task.setTaskCompleted(success: true)
        }
    }
}
