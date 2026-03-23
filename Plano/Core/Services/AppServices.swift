import Foundation
import OSLog

struct APIClient {
    var baseURL: URL?

    var modeLabel: String {
        if let baseURL {
            "Supabase • \(baseURL.host(percentEncoded: false) ?? baseURL.absoluteString)"
        } else {
            "Supabase not configured"
        }
    }
}

enum APIError: LocalizedError {
    case offline
    case unauthorized
    case invalidResponse
    case notConfigured(String)
    case notSupported(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .offline:
            "The request could not be completed because the device appears to be offline."
        case .unauthorized:
            "The session is no longer authorized for this action."
        case .invalidResponse:
            "The server returned data that could not be understood."
        case .notConfigured(let message):
            message
        case .notSupported(let message):
            message
        case .unknown:
            "An unknown networking error occurred."
        }
    }
}

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Plano"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let navigation = Logger(subsystem: subsystem, category: "navigation")
    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let search = Logger(subsystem: subsystem, category: "search")
    static let booking = Logger(subsystem: subsystem, category: "booking")
    static let shortcuts = Logger(subsystem: subsystem, category: "shortcuts")
    static let media = Logger(subsystem: subsystem, category: "media")
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
}
