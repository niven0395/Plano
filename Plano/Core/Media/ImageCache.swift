import Foundation
import OSLog
import UIKit
import CryptoKit

actor ImageCache {
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskDirectory: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskDirectory = caches.appendingPathComponent("PlanoImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)

        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
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
    }
}
