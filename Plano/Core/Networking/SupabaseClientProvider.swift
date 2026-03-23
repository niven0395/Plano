import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct SupabaseClientProvider {
    let configuration: SupabaseConfig?

    init(configuration: SupabaseConfig? = SupabaseConfig.current()) {
        self.configuration = configuration
    }

    var isConfigured: Bool {
        configuration != nil
    }

    var isSDKAvailable: Bool {
        #if canImport(Supabase)
        true
        #else
        false
        #endif
    }

    var isReadyForLiveServices: Bool {
        isConfigured && isSDKAvailable
    }

    func makeAPIClient() -> APIClient {
        APIClient(baseURL: configuration?.projectURL)
    }

    #if canImport(Supabase)
    func makeClient() -> SupabaseClient? {
        guard let configuration else { return nil }

        return SupabaseClient(
            supabaseURL: configuration.projectURL,
            supabaseKey: configuration.anonKey
        )
    }
    #endif
}
