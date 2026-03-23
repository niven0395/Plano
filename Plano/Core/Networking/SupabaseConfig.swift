import Foundation

struct SupabaseConfig: Hashable {
    let projectURL: URL
    let anonKey: String

    init?(projectURL: URL?, anonKey: String?) {
        guard let projectURL,
              let anonKey,
              !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        self.projectURL = projectURL
        self.anonKey = anonKey
    }

    static func current(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> SupabaseConfig? {
        let environment = processInfo.environment
        let rawURL = environment["SUPABASE_URL"]
            ?? bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        let rawAnonKey = environment["SUPABASE_ANON_KEY"]
            ?? bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String

        guard let sanitizedURL = sanitize(rawURL),
              let projectURL = URL(string: sanitizedURL),
              let anonKey = sanitize(rawAnonKey) else {
            return nil
        }

        return SupabaseConfig(projectURL: projectURL, anonKey: anonKey)
    }

    private static func sanitize(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("$("),
              trimmed != "REPLACE_ME" else {
            return nil
        }

        return trimmed
    }
}
