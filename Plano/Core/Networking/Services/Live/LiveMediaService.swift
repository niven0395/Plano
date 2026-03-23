import Foundation
import OSLog

#if canImport(Supabase)
import Supabase

actor LiveMediaService: MediaServiceProtocol {
    private let client: SupabaseClient
    private let signedURLCache: SignedURLCache
    private let bucket = "vendor-galleries"

    init(client: SupabaseClient, signedURLCache: SignedURLCache) {
        self.client = client
        self.signedURLCache = signedURLCache
    }

    func uploadImage(data: Data, vendorID: UUID) async throws -> String {
        let path = "\(vendorID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        _ = try await client.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
        return path
    }

    func uploadImageVariants(_ variants: [ImageSize: Data], vendorID: UUID) async throws -> String {
        let baseID = UUID().uuidString.lowercased()
        let basePath = "\(vendorID.uuidString.lowercased())/\(baseID)"

        // Upload both variants in parallel
        async let stdUpload: Void = {
            if let stdData = variants[.standard] {
                let path = basePath + ImageSize.standard.fileSuffix + ".jpg"
                _ = try await self.client.storage
                    .from(self.bucket)
                    .upload(path, data: stdData, options: FileOptions(contentType: "image/jpeg"))
            }
        }()

        async let thumbUpload: Void = {
            if let thumbData = variants[.thumbnail] {
                let path = basePath + ImageSize.thumbnail.fileSuffix + ".jpg"
                _ = try await self.client.storage
                    .from(self.bucket)
                    .upload(path, data: thumbData, options: FileOptions(contentType: "image/jpeg"))
            }
        }()

        _ = try await (stdUpload, thumbUpload)

        let inputKB = variants.values.reduce(0) { $0 + $1.count } / 1024
        AppLogger.media.info("Uploaded \(variants.count) variants (\(inputKB)KB total) for \(basePath)")

        return basePath
    }

    func deleteImage(path: String) async throws {
        if isLegacyPath(path) {
            _ = try await client.storage.from(bucket).remove(paths: [path])
        } else {
            let stdPath = path + ImageSize.standard.fileSuffix + ".jpg"
            let thumbPath = path + ImageSize.thumbnail.fileSuffix + ".jpg"
            _ = try await client.storage.from(bucket).remove(paths: [stdPath, thumbPath])
            // Also try legacy .jpg in case this is an old-format path that was stored without extension
            let legacyPath = path + ".jpg"
            _ = try? await client.storage.from(bucket).remove(paths: [legacyPath])
        }
    }

    func imageURL(for path: String) async throws -> URL {
        try await imageURL(for: path, size: .standard)
    }

    func imageURL(for path: String, size: ImageSize) async throws -> URL {
        let resolvedPath = resolveStoragePath(path, size: size)
        let cacheKey = resolvedPath

        if let cached = await signedURLCache.url(for: cacheKey) {
            return cached
        }

        let url = try await client.storage
            .from(bucket)
            .createSignedURL(path: resolvedPath, expiresIn: 60 * 60)

        await signedURLCache.store(url, for: cacheKey)
        return url
    }

    // MARK: - Path Resolution

    private func isLegacyPath(_ path: String) -> Bool {
        path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") || path.hasSuffix(".png")
    }

    private func resolveStoragePath(_ path: String, size: ImageSize) -> String {
        if isLegacyPath(path) {
            // Legacy path: return as-is regardless of requested size
            return path
        }
        // New variant path: append size suffix
        return path + size.fileSuffix + ".jpg"
    }
}
#else
actor LiveMediaService: MediaServiceProtocol {
    init(client: Any? = nil, signedURLCache: SignedURLCache? = nil) {}

    func uploadImage(data: Data, vendorID: UUID) async throws -> String {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func uploadImageVariants(_ variants: [ImageSize: Data], vendorID: UUID) async throws -> String {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func deleteImage(path: String) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func imageURL(for path: String) async throws -> URL {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func imageURL(for path: String, size: ImageSize) async throws -> URL {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }
}
#endif
