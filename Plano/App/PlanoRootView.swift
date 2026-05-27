import SwiftUI

struct PlanoRootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthStore.self) private var authStore
    @Environment(SessionStore.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(HostIdentityPromptStore.self) private var hostIdentityPromptStore
    @Environment(HostPlanningStore.self) private var hostPlanningStore
    @Environment(InboxStore.self) private var inboxStore
    @Environment(VendorOnboardingStore.self) private var vendorOnboardingStore
    @Environment(VendorDashboardStore.self) private var vendorDashboardStore
    @AppStorage("plano.host.hasSeenTour") private var hasSeenTour = false
    @State private var splashMinimumMet = false
    @State private var externalClaimCoordinator: ExternalBookingClaimCoordinator?
    @State private var lastSweepedUserID: UUID?

    var body: some View {
        @Bindable var router = router
        @Bindable var authStore = authStore
        @Bindable var session = session
        @Bindable var hostIdentityPromptStore = hostIdentityPromptStore

        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                NavigationStack(path: $router.homePath) {
                    HomeDestinationView()
                        .withDiscoveryDestinations()
                }
            }

            if session.currentRole == .vendor {
                Tab("Requests", systemImage: "tray.full.fill", value: .search) {
                    NavigationStack(path: $router.searchPath) {
                        VendorRequestsView(store: vendorDashboardStore)
                            .withDiscoveryDestinations()
                    }
                }
            }

            if !session.isAnonymous {
                Tab("Inbox", systemImage: "bubble.left.and.bubble.right.fill", value: .inbox) {
                    NavigationStack(path: $router.inboxPath) {
                        InboxView(store: inboxStore)
                            .navigationDestination(for: InboxRoute.self) { route in
                                switch route {
                                case .conversation(let conversationID):
                                    ConversationView(conversationID: conversationID)
                                }
                            }
                    }
                }
                .badge(inboxStore.unreadCount(for: session.currentRole))
            }

            if !session.isAnonymous && session.currentRole == .host {
                Tab("Planning", systemImage: "checklist", value: .events) {
                    NavigationStack(path: $router.planningPath) {
                        PlanningView()
                            .withDiscoveryDestinations()
                    }
                }
            }

            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                NavigationStack {
                    ProfileView()
                        .withDiscoveryDestinations()
                }
            }
        }
        .tint(AppTheme.Palette.accent)
        .hapticFeedback(.selection, trigger: router.selectedTab)
        .toolbarBackground(AppTheme.Palette.chrome, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let email = authStore.pendingVerificationEmail {
                EmailVerificationBanner(email: email, store: authStore)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(AppAnimation.transition, value: authStore.pendingVerificationEmail)
        .sheet(item: $authStore.presentedSheet) { mode in
            AuthView(mode: mode, store: authStore)
                .environment(environment)
        }
        .sheet(isPresented: $hostIdentityPromptStore.isPresented) {
            HostIdentityPromptView(store: hostIdentityPromptStore)
        }
        .sheet(isPresented: $session.requiresVendorOnboarding) {
            VendorOnboardingView(store: vendorOnboardingStore)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { session.isAuthenticated && session.currentRole == .host && !hasSeenTour },
                set: { if !$0 { hasSeenTour = true } }
            )
        ) {
            hasSeenTour = true
        } content: {
            HostOnboardingView()
        }
        .overlay {
            if session.identityState == .initializing || !splashMinimumMet {
                SplashScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
                    .zIndex(1)
            }
        }
        .animation(AppAnimation.transition, value: session.identityState == .initializing)
        .animation(AppAnimation.transition, value: splashMinimumMet)
        .task {
            try? await Task.sleep(for: .milliseconds(800))
            splashMinimumMet = true
        }
        .task {
            if externalClaimCoordinator == nil {
                externalClaimCoordinator = ExternalBookingClaimCoordinator(
                    claimService: environment.services.externalBookingClaimService,
                    sessionStore: session,
                    router: router
                )
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            guard let url = userActivity.webpageURL,
                  let route = ExternalBookingURL.route(from: url) else { return }
            handleExternalLinkRoute(route)
        }
        .onOpenURL { url in
            if let route = ExternalBookingURL.route(from: url) {
                handleExternalLinkRoute(route)
            }
        }
        .onChange(of: session.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated,
               let userID = session.currentUserID,
               lastSweepedUserID != userID {
                lastSweepedUserID = userID
                Task { await externalClaimCoordinator?.runPostSignInSweep() }
            } else if !isAuthenticated {
                lastSweepedUserID = nil
            }
        }
        // Role changes are handled by PlanoApp.handleRoleChange which also loads data
    }

    private func handleExternalLinkRoute(_ route: ExternalBookingLinkRoute) {
        switch route {
        case .vendorProfile(let vendorID):
            router.selectedTab = .home
            router.openVendorProfile(vendorID)
        case .claim(let token):
            Task { await externalClaimCoordinator?.handle(token: token) }
            if !session.isAuthenticated {
                authStore.presentSignIn()
            }
        }
    }
}

// MARK: - Discovery Destinations

private extension View {
    func withDiscoveryDestinations() -> some View {
        navigationDestination(for: DiscoveryRoute.self) { route in
            DiscoveryDestinationView(route: route)
        }
    }
}

// MARK: - Extracted Destination Views

private struct HomeDestinationView: View {
    @Environment(SessionStore.self) private var session
    @Environment(VendorDashboardStore.self) private var vendorDashboardStore

    var body: some View {
        switch session.currentRole {
        case .host:
            HomeView()
        case .vendor:
            VendorDashboardView(store: vendorDashboardStore)
        }
    }
}


private struct DiscoveryDestinationView: View {
    let route: DiscoveryRoute

    @Environment(AppEnvironment.self) private var environment
    @Environment(HostPlanningStore.self) private var hostPlanningStore
    @Environment(InboxStore.self) private var inboxStore
    @Environment(SessionStore.self) private var session
    @Environment(VendorDashboardStore.self) private var vendorDashboardStore
    @Environment(VendorProfileEditStore.self) private var vendorProfileEditStore

    var body: some View {
        switch route {
        case .vendorProfile(let vendorID):
            VendorProfileView(
                vendorID: vendorID,
                vendorProfileService: environment.services.vendorProfileService,
                analyticsService: environment.services.analyticsService,
                availabilityService: environment.services.availabilityService,
                sessionStore: session
            )
        case .vendorLeads:
            VendorRequestsView(store: vendorDashboardStore, showsNavigationBar: true)
        case .vendorLead(let request):
            VendorLeadDetailView(summary: request)
        case .categoryBrowse(let category):
            CategoryBrowseView(
                category: category,
                planner: hostPlanningStore,
                availabilityService: environment.services.availabilityService
            )
        case .vendorInsights:
            VendorInsightsView(analyticsService: environment.services.analyticsService)
        case .vendorRevenue:
            VendorRevenueDetailView()
        case .vendorAvailability:
            AvailabilityEditView(store: vendorProfileEditStore)
        case .vendorBlockDates:
            VendorBlockDatesView()
        case .vendorAllWork:
            VendorAllWorkView()
        case .bookingDetail(let conversationID):
            BookingDetailView(conversationID: conversationID)
        }
    }
}
