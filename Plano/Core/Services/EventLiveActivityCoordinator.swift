import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct EventCountdownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var countdownLabel: String
        var detail: String
    }

    let title: String
    let venue: String
}
#endif

enum LiveActivityTrackingMode {
    case system
    case preview
}

@MainActor
final class EventLiveActivityCoordinator {
    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private var activitiesByEventID: [UUID: Activity<EventCountdownAttributes>] = [:]
    #endif

    func startTracking(
        eventID: UUID,
        title: String,
        venue: String,
        countdownLabel: String,
        detail: String
    ) async -> LiveActivityTrackingMode {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *),
           ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                let content = ActivityContent(
                    state: EventCountdownAttributes.ContentState(
                        countdownLabel: countdownLabel,
                        detail: detail
                    ),
                    staleDate: nil
                )
                let activity = try Activity<EventCountdownAttributes>.request(
                    attributes: EventCountdownAttributes(title: title, venue: venue),
                    content: content,
                    pushType: nil
                )
                activitiesByEventID[eventID] = activity
                return .system
            } catch {
                return .preview
            }
        }
        #endif

        return .preview
    }

    func stopTracking(eventID: UUID) async {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *),
           let activity = activitiesByEventID.removeValue(forKey: eventID) {
            await activity.end(
                ActivityContent(
                    state: activity.content.state,
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
        }
        #endif
    }
}
