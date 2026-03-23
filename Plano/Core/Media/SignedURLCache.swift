import Foundation
import OSLog

actor SignedURLCache {
    private struct Entry {
        let url: URL
        let expiresAt: Date
    }

    /// TTL of 50 minutes (10 min margin before 60-min signed URL expiry)
    private let ttl: TimeInterval = 50 * 60
    private var entries: [String: Entry] = [:]

    func url(for key: String) -> URL? {
        guard let entry = entries[key], entry.expiresAt > Date.now else {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.url
    }

    func store(_ url: URL, for key: String) {
        entries[key] = Entry(url: url, expiresAt: Date.now.addingTimeInterval(ttl))
    }

    func invalidate(for key: String) {
        entries.removeValue(forKey: key)
    }
}
