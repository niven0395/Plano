import Foundation
import OSLog

struct ServiceContainer {
    let apiClient: APIClient
    let authService: any AuthServiceProtocol
    let vendorSearchService: any VendorSearchServiceProtocol
    let vendorProfileService: any VendorProfileServiceProtocol
    let mediaService: any MediaServiceProtocol
    let bookingService: any BookingServiceProtocol
    let messagingService: any MessagingServiceProtocol
    let availabilityService: any VendorAvailabilityServiceProtocol
    let analyticsService: any AnalyticsServiceProtocol
    let externalBookingClaimService: any ExternalBookingClaimServiceProtocol
    let signedURLCache: SignedURLCache
    let isConfigured: Bool
    let supportsAppleSignIn: Bool

    static func makeDefault(defaults: UserDefaults = .standard) -> ServiceContainer {
        let provider = SupabaseClientProvider()
        let apiClient = provider.makeAPIClient()
        let signedURLCache = SignedURLCache()
        let unavailableMessage: String

        if provider.isSDKAvailable {
            unavailableMessage = "Supabase is not configured yet. Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` to run auth, discovery, and booking."
        } else {
            unavailableMessage = "The Supabase SDK is not available in this build."
        }

        #if canImport(Supabase)
        if let client = provider.makeClient() {
            AppLogger.networking.notice(
                "Using live Supabase services at \(apiClient.modeLabel, privacy: .public)"
            )

            return ServiceContainer(
                apiClient: apiClient,
                authService: LiveAuthService(client: client),
                vendorSearchService: LiveVendorSearchService(client: client),
                vendorProfileService: LiveVendorProfileService(client: client),
                mediaService: LiveMediaService(client: client, signedURLCache: signedURLCache),
                bookingService: LiveBookingService(client: client),
                messagingService: LiveMessagingService(client: client),
                availabilityService: LiveVendorAvailabilityService(client: client),
                analyticsService: LiveAnalyticsService(client: client),
                externalBookingClaimService: LiveExternalBookingClaimService(client: client),
                signedURLCache: signedURLCache,
                isConfigured: true,
                supportsAppleSignIn: true
            )
        }
        #endif

        AppLogger.networking.notice(
            "Supabase services unavailable at \(apiClient.modeLabel, privacy: .public)"
        )

        return ServiceContainer(
            apiClient: apiClient,
            authService: UnavailableAuthService(message: unavailableMessage),
            vendorSearchService: UnavailableVendorSearchService(message: unavailableMessage),
            vendorProfileService: UnavailableVendorProfileService(message: unavailableMessage),
            mediaService: UnavailableMediaService(message: unavailableMessage),
            bookingService: UnavailableBookingService(message: unavailableMessage),
            messagingService: UnavailableMessagingService(message: unavailableMessage),
            availabilityService: UnavailableVendorAvailabilityService(message: unavailableMessage),
            analyticsService: UnavailableAnalyticsService(message: unavailableMessage),
            externalBookingClaimService: UnavailableExternalBookingClaimService(message: unavailableMessage),
            signedURLCache: signedURLCache,
            isConfigured: false,
            supportsAppleSignIn: false
        )
    }
}
