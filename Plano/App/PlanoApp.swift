import SwiftUI
import SwiftData
import OSLog
#if canImport(TipKit)
import TipKit
#endif

@main
struct PlanoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var environment: AppEnvironment
    @State private var authStore: AuthStore
    @State private var sessionStore: SessionStore
    @State private var router: AppRouter
    @State private var hostIdentityPromptStore: HostIdentityPromptStore
    @State private var hostPlanningStore: HostPlanningStore
    @State private var searchStore: SearchStore
    @State private var inboxStore: InboxStore
    @State private var requestsStore: RequestsStore
    @State private var eventsStore: EventsStore
    @State private var shortcutsEnabled = true
    @State private var profilePreferences = ProfilePreferences()
    @State private var vendorOnboardingStore: VendorOnboardingStore
    @State private var vendorProfileEditStore: VendorProfileEditStore
    @State private var vendorDashboardStore: VendorDashboardStore
    @State private var eventWorkspaceStore: EventWorkspaceStore
    @State private var networkMonitor: NetworkMonitor
    @State private var realtimeManager: RealtimeManager
    @State private var pushNotificationManager: PushNotificationManager
    @State private var didConfigureTips = false
    @State private var lastForegroundRefreshAt: Date?
    private let messageCacheManager: MessageCacheManager?

    private static let cacheStoreURL = URL.applicationSupportDirectory.appending(path: "PlanoMessageCache.store")

    init() {
        // Set up SwiftData for local message caching
        let cacheManager = Self.createCacheManager()
        self.messageCacheManager = cacheManager

        BackgroundMessageRefresh.register()

        let services = ServiceContainer.makeDefault()
        let environment = AppEnvironment(services: services)
        let sessionStore = SessionStore()
        let authStore = AuthStore(
            authService: services.authService,
            sessionStore: sessionStore,
            supportsAppleSignIn: services.supportsAppleSignIn
        )
        let hostIdentityPromptStore = HostIdentityPromptStore(authStore: authStore)
        let hostPlanningStore = HostPlanningStore(
            eventService: services.eventService,
            vendorSearchService: services.vendorSearchService,
            plannedVendorService: services.plannedVendorService
        )
        let realtimeManager = RealtimeManager()
        let networkMonitor = NetworkMonitor()
        let pushNotificationManager = PushNotificationManager(messagingService: services.messagingService)

        #if canImport(Supabase)
        if let client = SupabaseClientProvider().makeClient() {
            realtimeManager.configure(client: client)
        }
        #endif

        let inboxStore = InboxStore(
            bookingService: services.bookingService,
            messagingService: services.messagingService,
            vendorProfileService: services.vendorProfileService,
            sessionStore: sessionStore
        )
        inboxStore.realtimeManager = realtimeManager
        inboxStore.networkMonitor = networkMonitor
        inboxStore.analyticsService = services.analyticsService
        inboxStore.messageCacheManager = cacheManager
        inboxStore.configureOfflineQueue()
        inboxStore.configureRealtimeCallbacks()
        let vendorProfileEditStore = VendorProfileEditStore(
            vendorProfileService: services.vendorProfileService,
            mediaService: services.mediaService,
            availabilityService: services.availabilityService,
            imageProcessor: environment.imageProcessor,
            imageCache: environment.imageCache,
            sessionStore: sessionStore
        )
        let vendorOnboardingStore = VendorOnboardingStore(
            vendorProfileService: services.vendorProfileService,
            mediaService: services.mediaService,
            imageProcessor: environment.imageProcessor,
            imageCache: environment.imageCache,
            sessionStore: sessionStore
        )
        let vendorDashboardStore = VendorDashboardStore(
            bookingService: services.bookingService,
            analyticsService: services.analyticsService,
            sessionStore: sessionStore,
            inboxStore: inboxStore
        )

        _environment = State(initialValue: environment)
        _authStore = State(initialValue: authStore)
        _sessionStore = State(initialValue: sessionStore)
        let router = AppRouter()
        router.inboxStore = inboxStore
        _router = State(initialValue: router)
        _hostIdentityPromptStore = State(initialValue: hostIdentityPromptStore)
        _hostPlanningStore = State(initialValue: hostPlanningStore)
        _searchStore = State(initialValue: SearchStore(
            planner: hostPlanningStore,
            availabilityService: services.availabilityService,
            analyticsService: services.analyticsService
        ))
        let eventsStore = EventsStore(bookingService: services.bookingService, sessionStore: sessionStore)
        let eventWorkspaceStore = EventWorkspaceStore(
            planner: hostPlanningStore,
            inboxStore: inboxStore,
            vendorDashboardStore: vendorDashboardStore,
            bookingService: services.bookingService
        )
        inboxStore.onStageChanged = { [weak eventsStore, weak eventWorkspaceStore] in
            eventsStore?.invalidate()
            eventWorkspaceStore?.invalidateAllCoVendorCaches()
        }

        _inboxStore = State(initialValue: inboxStore)
        _requestsStore = State(initialValue: RequestsStore(planner: hostPlanningStore, inboxStore: inboxStore))
        _eventsStore = State(initialValue: eventsStore)
        _vendorOnboardingStore = State(initialValue: vendorOnboardingStore)
        _vendorProfileEditStore = State(initialValue: vendorProfileEditStore)
        _vendorDashboardStore = State(initialValue: vendorDashboardStore)
        _eventWorkspaceStore = State(initialValue: eventWorkspaceStore)
        _networkMonitor = State(initialValue: networkMonitor)
        _realtimeManager = State(initialValue: realtimeManager)
        _pushNotificationManager = State(initialValue: pushNotificationManager)
    }

    var body: some Scene {
        WindowGroup {
            PlanoRootView()
            .withPlanoDependencies(
                environment: environment,
                authStore: authStore,
                sessionStore: sessionStore,
                router: router,
                hostIdentityPromptStore: hostIdentityPromptStore,
                hostPlanningStore: hostPlanningStore,
                searchStore: searchStore,
                inboxStore: inboxStore,
                requestsStore: requestsStore,
                eventsStore: eventsStore,
                vendorOnboardingStore: vendorOnboardingStore,
                vendorProfileEditStore: vendorProfileEditStore,
                vendorDashboardStore: vendorDashboardStore,
                eventWorkspaceStore: eventWorkspaceStore,
                networkMonitor: networkMonitor,
                realtimeManager: realtimeManager,
                profilePreferences: profilePreferences,
                pushNotificationManager: pushNotificationManager
            )
            .task {
                configureTipsIfNeeded()
                networkMonitor.start { [weak inboxStore, weak realtimeManager] isConnected in
                    realtimeManager?.handleConnectivityChange(isConnected: isConnected)
                    if isConnected {
                        inboxStore?.drainOfflineQueue()
                    }
                }
                await pushNotificationManager.requestPermission()
                await authStore.restoreSessionIfNeeded()
            }
            .onChange(of: sessionStore.identityState) { oldState, newState in
                handleIdentityStateChange(from: oldState, to: newState)
            }
            .onChange(of: sessionStore.currentRole) { _, newRole in
                handleRoleChange(newRole)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, sessionStore.canBrowse {
                    handlePendingShortcutAction()
                    Task { await inboxStore.catchUpAfterReconnect() }
                    refreshStaleStoresIfNeeded()
                }
                if newPhase == .background {
                    BackgroundMessageRefresh.schedule()
                    Task { await environment.services.analyticsService.flush() }
                }
            }
        }
    }

    private func configureTipsIfNeeded() {
        guard !didConfigureTips else { return }
        didConfigureTips = true

        #if canImport(TipKit)
        do {
            try Tips.configure([
                .displayFrequency(.immediate),
            ])
        } catch {
            AppLogger.app.error("TipKit configuration failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    private func handlePendingShortcutAction() {
        guard sessionStore.canBrowse,
              shortcutsEnabled,
              let action = ShortcutLaunchCenter.consume() else {
            return
        }

        switch action {
        case .pendingRequests:
            if sessionStore.currentRole == .vendor {
                router.selectedTab = .search
            } else {
                router.showEventTabRoot()
            }

        case .todayEvents:
            if sessionStore.currentRole == .vendor,
               let workspace = eventWorkspaceStore.vendorWorkspaces.first {
                router.openVendorEventWorkspace(workspace.id)
            } else if let nextEvent = hostPlanningStore.events.sorted(by: { $0.date < $1.date }).first {
                hostPlanningStore.selectEvent(nextEvent.id)
                router.openHostEventWorkspace(nextEvent.id)
            } else {
                router.showEventTabRoot()
            }

        case .continueLatestConversation:
            if let conversationID = inboxStore.latestConversationID(for: sessionStore.currentRole) {
                router.openConversation(conversationID)
            } else {
                router.selectedTab = .inbox
            }

        case .searchPhotographers:
            searchStore.applyShortcutSearch(category: .photographer, query: "Toronto photographers")
            router.selectedTab = .home
        }

        AppLogger.shortcuts.notice("Handled shortcut action \(action.rawValue, privacy: .public)")
    }

    private func handleIdentityStateChange(from oldState: SessionIdentityState, to newState: SessionIdentityState) {
        switch newState {
        case .initializing:
            break

        case .anonymous, .identified:
            router.resetAllPaths()
            router.selectedTab = .home

            if oldState == .authenticated {
                hostPlanningStore.prepareForSignedOutState()
                searchStore.reset()
                vendorProfileEditStore.reset()
            }

            Task {
                await hostPlanningStore.loadIfNeeded()
                await inboxStore.loadConversations(for: .host)
                searchStore.syncToSelectedEvent()
                await searchStore.loadIfNeeded()
            }
            inboxStore.syncHostIdentityFromSession()
            vendorDashboardStore.reset()
            eventsStore.reset()

        case .authenticated:
            router.resetAllPaths()
            loadDataForCurrentRole()
        }
    }

    private func handleRoleChange(_ role: UserRole) {
        guard sessionStore.identityState == .authenticated else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            router.resetAllPaths()
        }
        loadDataForCurrentRole(navigateToDefaultTab: false)
    }

    private static func createCacheManager() -> MessageCacheManager? {
        let schema = Schema([CachedMessage.self, CachedConversation.self, CachedAttachment.self])
        let storeURL = cacheStoreURL

        do {
            let config = ModelConfiguration("PlanoMessageCache", schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [config])
            return MessageCacheManager(modelContainer: container)
        } catch {
            AppLogger.app.error("Message cache migration failed, recreating store: \(error.localizedDescription, privacy: .public)")

            // Delete the store and its WAL companions
            let fileManager = FileManager.default
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = storeURL.deletingPathExtension().appendingPathExtension(storeURL.pathExtension + suffix)
                try? fileManager.removeItem(at: fileURL)
            }

            // Retry once with a fresh store
            do {
                let config = ModelConfiguration("PlanoMessageCache", schema: schema, url: storeURL)
                let container = try ModelContainer(for: schema, configurations: [config])
                AppLogger.app.notice("Message cache store recreated successfully")
                return MessageCacheManager(modelContainer: container)
            } catch {
                AppLogger.app.error("Message cache retry also failed, disabling cache: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }

    private func loadDataForCurrentRole(navigateToDefaultTab: Bool = true) {
        switch sessionStore.currentRole {
        case .host:
            if navigateToDefaultTab { router.selectedTab = .home }
            vendorDashboardStore.reset()

            Task {
                async let plannerLoad: Void = hostPlanningStore.loadIfNeeded()
                async let inboxLoad: Void = inboxStore.loadConversations(for: .host)

                await plannerLoad
                searchStore.syncToSelectedEvent()
                await searchStore.loadIfNeeded()
                _ = await inboxLoad
            }
            inboxStore.syncHostIdentityFromSession()

        case .vendor:
            if navigateToDefaultTab { router.selectedTab = .home }
            hostPlanningStore.prepareForSignedOutState()
            searchStore.reset()

            Task {
                async let e: Void = eventsStore.loadIfNeeded()
                async let d: Void = vendorDashboardStore.loadIfNeeded()
                async let i: Void = inboxStore.loadConversations(for: .vendor)
                async let p: Void = vendorProfileEditStore.loadIfNeeded()
                _ = await (e, d, i, p)
            }
        }

        lastForegroundRefreshAt = .now
    }

    private func refreshStaleStoresIfNeeded() {
        let staleThreshold: TimeInterval = 60
        guard let lastRefresh = lastForegroundRefreshAt,
              Date.now.timeIntervalSince(lastRefresh) >= staleThreshold else { return }
        lastForegroundRefreshAt = .now

        switch sessionStore.currentRole {
        case .host:
            Task {
                async let p: Void = hostPlanningStore.load()
                async let i: Void = inboxStore.loadConversations(for: .host)
                await p; _ = await i
                searchStore.syncToSelectedEvent()
                await searchStore.load()
            }
        case .vendor:
            Task {
                async let e: Void = eventsStore.loadVendorEvents()
                async let d: Void = vendorDashboardStore.load()
                async let i: Void = inboxStore.loadConversations(for: .vendor)
                async let p: Void = vendorProfileEditStore.load()
                _ = await (e, d, i, p)
            }
        }
    }
}

// MARK: - Centralized Environment Injection

private extension View {
    func withPlanoDependencies(
        environment: AppEnvironment,
        authStore: AuthStore,
        sessionStore: SessionStore,
        router: AppRouter,
        hostIdentityPromptStore: HostIdentityPromptStore,
        hostPlanningStore: HostPlanningStore,
        searchStore: SearchStore,
        inboxStore: InboxStore,
        requestsStore: RequestsStore,
        eventsStore: EventsStore,
        vendorOnboardingStore: VendorOnboardingStore,
        vendorProfileEditStore: VendorProfileEditStore,
        vendorDashboardStore: VendorDashboardStore,
        eventWorkspaceStore: EventWorkspaceStore,
        networkMonitor: NetworkMonitor,
        realtimeManager: RealtimeManager,
        profilePreferences: ProfilePreferences,
        pushNotificationManager: PushNotificationManager
    ) -> some View {
        self
            .environment(environment)
            .environment(authStore)
            .environment(sessionStore)
            .environment(router)
            .environment(hostIdentityPromptStore)
            .environment(hostPlanningStore)
            .environment(searchStore)
            .environment(inboxStore)
            .environment(requestsStore)
            .environment(eventsStore)
            .environment(vendorOnboardingStore)
            .environment(vendorProfileEditStore)
            .environment(vendorDashboardStore)
            .environment(eventWorkspaceStore)
            .environment(networkMonitor)
            .environment(realtimeManager)
            .environment(profilePreferences)
            .environment(pushNotificationManager)
            .environment(\.hapticsEnabled, profilePreferences.hapticsEnabled)
    }
}
