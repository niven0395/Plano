import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let services: ServiceContainer
    let apiClient: APIClient
    let imageCache: ImageCache
    let imageProcessor: ImageProcessor
    let buildLabel: String

    init(
        services: ServiceContainer,
        buildLabel: String = "Plano"
    ) {
        self.services = services
        apiClient = services.apiClient
        imageCache = ImageCache()
        imageProcessor = ImageProcessor()
        self.buildLabel = buildLabel
    }

    var transportSummary: String {
        services.isConfigured
            ? "Live Supabase auth, discovery, and booking services are active."
            : "Supabase credentials are missing, so live auth, discovery, and booking calls will stay unavailable until the project is configured."
    }
}

@MainActor
@Observable
final class SessionStore {
    private static let roleKey = "plano.session.role"

    private let defaults: UserDefaults
    private(set) var identityState: SessionIdentityState = .initializing
    private(set) var anonymousSession: AnonymousHostSession?
    private(set) var authenticatedProfile: AuthenticatedUserProfile?
    var currentRole: UserRole {
        didSet {
            guard currentRole != oldValue else { return }

            guard availableRoles.contains(currentRole) else {
                currentRole = oldValue
                return
            }

            defaults.set(currentRole.rawValue, forKey: Self.roleKey)
            AppLogger.app.notice("Switched app role to \(self.currentRole.rawValue, privacy: .public)")
        }
    }
    var requiresVendorOnboarding = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedRole = UserRole(rawValue: defaults.string(forKey: Self.roleKey) ?? "")
        currentRole = storedRole ?? .host
    }

    var canBrowse: Bool {
        identityState != .initializing
    }

    var isAnonymous: Bool {
        switch identityState {
        case .anonymous, .identified:
            true
        case .initializing, .authenticated:
            false
        }
    }

    var isAuthenticated: Bool {
        identityState == .authenticated && authenticatedProfile != nil
    }

    var isVendorAuthenticated: Bool {
        isAuthenticated && (authenticatedProfile?.isVendorOnboarded ?? false)
    }

    var canMessage: Bool {
        switch identityState {
        case .identified, .authenticated:
            true
        case .initializing, .anonymous:
            false
        }
    }

    var needsNamePrompt: Bool {
        identityState == .anonymous
    }

    var availableRoles: [UserRole] {
        if isVendorAuthenticated {
            [.host, .vendor]
        } else {
            [.host]
        }
    }

    var currentUserID: UUID? {
        authenticatedProfile?.userID ?? anonymousSession?.userID
    }

    var currentDisplayName: String {
        switch identityState {
        case .initializing, .anonymous:
            "Guest host"
        case .identified(let name):
            name
        case .authenticated:
            authenticatedProfile?.displayName(for: currentRole) ?? "Plano User"
        }
    }

    var currentSubtitle: String {
        switch (identityState, currentRole) {
        case (.authenticated, .vendor):
            "Persistent business identity with lead and booking management."
        case (.authenticated, .host):
            "Signed in. Browse vendors, plan events, and manage bookings."
        case (.initializing, _), (.anonymous, _), (.identified, _):
            "Browse vendors fast. Add your name only when you need to reach out."
        }
    }

    var hostName: String {
        if let profile = authenticatedProfile {
            return profile.personalDisplayName
        }
        return anonymousSession?.resolvedDisplayName ?? "Guest host"
    }

    var vendorName: String {
        authenticatedProfile?.vendorDisplayName ?? "Vendor"
    }

    func resetToAnonymous() {
        authenticatedProfile = nil
        anonymousSession = nil
        requiresVendorOnboarding = false
        identityState = .anonymous
        currentRole = .host
    }

    func beginInitialization() {
        identityState = .initializing
    }

    func applyAnonymousSession(_ session: AnonymousHostSession) {
        anonymousSession = session
        authenticatedProfile = nil
        requiresVendorOnboarding = false
        identityState = session.identityState
        currentRole = .host
    }

    func applyAuthenticatedSession(_ profile: AuthenticatedUserProfile, preferredRole: UserRole? = nil) {
        authenticatedProfile = profile
        anonymousSession = nil
        identityState = .authenticated

        if let preferredRole, availableRolesFor(profile).contains(preferredRole) {
            currentRole = preferredRole
        } else if profile.isVendorOnboarded, availableRolesFor(profile).contains(currentRole) {
            // Keep current role if it's still valid
        } else {
            currentRole = .host
        }
    }

    func beginVendorOnboarding() {
        requiresVendorOnboarding = true
    }

    func completeVendorOnboarding(with profile: AuthenticatedUserProfile) {
        authenticatedProfile = profile
        identityState = .authenticated
        currentRole = .vendor
    }

    func supportsRole(_ role: UserRole) -> Bool {
        availableRoles.contains(role)
    }

    private func availableRolesFor(_ profile: AuthenticatedUserProfile) -> [UserRole] {
        if profile.isVendorOnboarded {
            [.host, .vendor]
        } else {
            [.host]
        }
    }
}

enum InboxRoute: Hashable {
    case conversation(UUID)
}

enum DiscoveryRoute: Hashable {
    case vendorProfile(UUID)
    case vendorLeads
    case vendorLead(BookingRequestSummary)
    case categoryBrowse(VendorCategory)
    case vendorInsights
    case vendorRevenue
    case vendorAvailability
    case vendorBlockDates
    case vendorAllWork
    case bookingDetail(UUID)
}

enum ShortcutLaunchAction: String {
    case pendingRequests
    case continueLatestConversation
    case searchPhotographers
}

enum ShortcutLaunchCenter {
    nonisolated static func queue(_ action: ShortcutLaunchAction, defaults: UserDefaults = .standard) {
        defaults.set(action.rawValue, forKey: "plano.shortcuts.pending-action")
    }

    nonisolated static func consume(defaults: UserDefaults = .standard) -> ShortcutLaunchAction? {
        defer {
            defaults.removeObject(forKey: "plano.shortcuts.pending-action")
        }

        guard let rawValue = defaults.string(forKey: "plano.shortcuts.pending-action") else {
            return nil
        }

        return ShortcutLaunchAction(rawValue: rawValue)
    }
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath: [DiscoveryRoute] = []
    var searchPath: [DiscoveryRoute] = []
    var inboxPath: [InboxRoute] = []
    var planningPath: [DiscoveryRoute] = []

    @ObservationIgnored weak var inboxStore: InboxStore?

    func resetDiscoveryPaths() {
        homePath = []
        searchPath = []
    }

    func resetAllPaths() {
        resetDiscoveryPaths()
        inboxPath = []
        planningPath = []
    }

    func openConversation(_ conversationID: UUID) {
        Task { await inboxStore?.loadMessages(for: conversationID) }
        selectedTab = .inbox
        inboxPath = [.conversation(conversationID)]
    }

    func openVendorProfile(_ vendorID: UUID) {
        resetDiscoveryPaths()
        selectedTab = .home
        homePath = [.vendorProfile(vendorID)]
    }

}
