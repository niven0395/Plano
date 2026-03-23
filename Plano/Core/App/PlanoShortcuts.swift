import AppIntents

struct OpenPendingRequestsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Pending Requests"
    static let description = IntentDescription("Open the vendor request queue.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            ShortcutLaunchCenter.queue(.pendingRequests)
        }
        return .result(dialog: "Opening pending requests.")
    }
}

struct ViewTodayEventsIntent: AppIntent {
    static let title: LocalizedStringResource = "View Today’s Events"
    static let description = IntentDescription("Open the next relevant event workspace.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            ShortcutLaunchCenter.queue(.todayEvents)
        }
        return .result(dialog: "Opening your events.")
    }
}

struct ContinueLatestConversationIntent: AppIntent {
    static let title: LocalizedStringResource = "Continue Latest Conversation"
    static let description = IntentDescription("Jump back into the most recent host conversation.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            ShortcutLaunchCenter.queue(.continueLatestConversation)
        }
        return .result(dialog: "Opening your latest conversation.")
    }
}

struct SearchPhotographersIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Photographers"
    static let description = IntentDescription("Open search with photographer discovery ready.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            ShortcutLaunchCenter.queue(.searchPhotographers)
        }
        return .result(dialog: "Opening photographer search.")
    }
}

struct PlanoShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPendingRequestsIntent(),
            phrases: [
                "Open pending requests in \(.applicationName)",
                "Show vendor requests in \(.applicationName)",
            ],
            shortTitle: "Pending Requests",
            systemImageName: "tray.full.fill"
        )

        AppShortcut(
            intent: ViewTodayEventsIntent(),
            phrases: [
                "Show today events in \(.applicationName)",
                "Open my events in \(.applicationName)",
            ],
            shortTitle: "Today’s Events",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: ContinueLatestConversationIntent(),
            phrases: [
                "Continue my latest conversation in \(.applicationName)",
                "Open recent chat in \(.applicationName)",
            ],
            shortTitle: "Latest Chat",
            systemImageName: "bubble.left.and.bubble.right.fill"
        )

        AppShortcut(
            intent: SearchPhotographersIntent(),
            phrases: [
                "Search photographers in \(.applicationName)",
                "Find photographers in \(.applicationName)",
            ],
            shortTitle: "Photographers",
            systemImageName: "camera.fill"
        )
    }
}
