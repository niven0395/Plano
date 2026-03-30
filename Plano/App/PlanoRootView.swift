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
    @Environment(RequestsStore.self) private var requestsStore

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
                    NavigationStack(path: $router.eventsPath) {
                        EventListView()
                            .navigationDestination(for: EventsRoute.self) { route in
                                switch route {
                                case .eventDetail(let eventID):
                                    EventDetailView(eventID: eventID)
                                case .eventPlanning(let eventID):
                                    EventDetailView(eventID: eventID)
                                case .hostWorkspace(let eventID):
                                    EventDetailView(eventID: eventID)
                                case .vendorWorkspace(let workspaceID):
                                    VendorEventWorkspaceView(workspaceID: workspaceID)
                                }
                            }
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
        .overlay(alignment: .top) {
            if session.identityState == .initializing {
                AppSurface {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(AppTheme.Palette.accent)

                        Text("Preparing guest session")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                    .padding(.vertical, 10)
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 10)
            }
        }
        // Role changes are handled by PlanoApp.handleRoleChange which also loads data
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
    @Environment(EventWorkspaceStore.self) private var workspaceStore

    var body: some View {
        switch route {
        case .vendorProfile(let vendorID):
            VendorProfileView(
                store: VendorProfileStore(
                    vendorID: vendorID,
                    vendorProfileService: environment.services.vendorProfileService,
                    analyticsService: environment.services.analyticsService,
                    availabilityService: environment.services.availabilityService,
                    sessionStore: session
                )
            )
        case .vendorLeads:
            VendorRequestsView(store: vendorDashboardStore, showsNavigationBar: true)
        case .vendorLead(let request):
            VendorLeadDetailView(summary: request)
        case .eventWorkspace(let eventID):
            EventDetailView(eventID: eventID)
        case .categoryBrowse(let category):
            CategoryBrowseView(
                store: CategoryBrowseStore(
                    category: category,
                    planner: hostPlanningStore,
                    availabilityService: environment.services.availabilityService
                )
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
        }
    }
}
