import Foundation
import OSLog
import UIKit
import CryptoKit

actor ImageCache {
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskDirectory: URL
    private let maxDiskBytes: Int = 200 * 1024 * 1024 // 200MB
    private var estimatedDiskBytes: Int = 0

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskDirectory = caches.appendingPathComponent("PlanoImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)

        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB

        estimatedDiskBytes = measureDiskUsage()
    }

    // MARK: - Image Caching

    func image(for storagePath: String, size: ImageSize) -> UIImage? {
        let key = cacheKey(storagePath: storagePath, size: size)

        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        if let diskData = diskData(for: key), let image = UIImage(data: diskData) {
            let cost = diskData.count
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        }

        return nil
    }

    func store(_ image: UIImage, data: Data?, for storagePath: String, size: ImageSize) {
        let key = cacheKey(storagePath: storagePath, size: size)
        let cost = data?.count ?? 0
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)

        if let data {
            writeToDisk(data, key: key)
        }
    }

    func clearAllStagedImages() {
        stagedImages.removeAll()
    }

    // MARK: - Local Staging (optimistic display)

    private var stagedImages: [String: UIImage] = [:]

    func stageLocalImage(_ image: UIImage, for storagePath: String) {
        stagedImages[storagePath] = image
    }

    func stagedImage(for storagePath: String) -> UIImage? {
        stagedImages[storagePath]
    }

    func removeStagedImage(for storagePath: String) {
        stagedImages.removeValue(forKey: storagePath)
    }

    // MARK: - Private

    private func cacheKey(storagePath: String, size: ImageSize) -> String {
        let input = "\(storagePath):\(size.rawValue)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func diskURL(for key: String) -> URL {
        diskDirectory.appendingPathComponent(key)
    }

    private func diskData(for key: String) -> Data? {
        let url = diskURL(for: key)
        return try? Data(contentsOf: url)
    }

    private func writeToDisk(_ data: Data, key: String) {
        let url = diskURL(for: key)
        try? data.write(to: url, options: .atomic)
        estimatedDiskBytes += data.count

        if estimatedDiskBytes > maxDiskBytes {
            evictOldestFiles()
        }
    }

    private func measureDiskUsage() -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: diskDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += size
        }
        return total
    }

    private func evictOldestFiles() {
        guard let enumerator = FileManager.default.enumerator(
            at: diskDirectory,
            includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var files: [(url: URL, accessDate: Date, size: Int)] = []
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.contentAccessDateKey, .fileSizeKey])
            let date = values?.contentAccessDate ?? .distantPast
            let size = values?.fileSize ?? 0
            files.append((fileURL, date, size))
        }

        // Oldest first
        files.sort { $0.accessDate < $1.accessDate }

        let targetBytes = maxDiskBytes * 3 / 4 // Evict down to 75% to avoid repeated evictions
        var currentBytes = estimatedDiskBytes

        for file in files {
            guard currentBytes > targetBytes else { break }
            try? FileManager.default.removeItem(at: file.url)
            currentBytes -= file.size
        }

        estimatedDiskBytes = currentBytes
    }
}
