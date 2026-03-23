import Foundation

@MainActor
@Observable
final class ProfilePreferences {
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    var notifyMessages: Bool {
        didSet { defaults.set(notifyMessages, forKey: Keys.notifyMessages) }
    }

    var notifyBookings: Bool {
        didSet { defaults.set(notifyBookings, forKey: Keys.notifyBookings) }
    }

    var notifyReminders: Bool {
        didSet { defaults.set(notifyReminders, forKey: Keys.notifyReminders) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        self.notifyMessages = defaults.object(forKey: Keys.notifyMessages) as? Bool ?? true
        self.notifyBookings = defaults.object(forKey: Keys.notifyBookings) as? Bool ?? true
        self.notifyReminders = defaults.object(forKey: Keys.notifyReminders) as? Bool ?? true
    }

    private enum Keys {
        static let hapticsEnabled = "plano.preferences.hapticsEnabled"
        static let notifyMessages = "plano.preferences.notifyMessages"
        static let notifyBookings = "plano.preferences.notifyBookings"
        static let notifyReminders = "plano.preferences.notifyReminders"
    }
}
