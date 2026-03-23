import Foundation

protocol MediaServiceProtocol {
    func uploadImage(data: Data, vendorID: UUID) async throws -> String
    func uploadImageVariants(_ variants: [ImageSize: Data], vendorID: UUID) async throws -> String
    func deleteImage(path: String) async throws
    func imageURL(for path: String) async throws -> URL
    func imageURL(for path: String, size: ImageSize) async throws -> URL
}

extension MediaServiceProtocol {
    func uploadImageVariants(_ variants: [ImageSize: Data], vendorID: UUID) async throws -> String {
        guard let standardData = variants[.standard] else {
            throw ImageProcessingError.processingFailed
        }
        return try await uploadImage(data: standardData, vendorID: vendorID)
    }

    func imageURL(for path: String, size: ImageSize) async throws -> URL {
        try await imageURL(for: path)
    }
}
