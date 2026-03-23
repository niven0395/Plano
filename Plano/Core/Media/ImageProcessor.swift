import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

actor ImageProcessor {
    func processVariants(from rawData: Data) throws -> [ImageSize: Data] {
        guard let source = CGImageSourceCreateWithData(rawData as CFData, nil) else {
            throw ImageProcessingError.invalidSourceData
        }

        var results: [ImageSize: Data] = [:]

        for size in ImageSize.allCases {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(size.maxDimension),
            ]

            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                AppLogger.media.warning("Failed to create \(size.rawValue) thumbnail")
                continue
            }

            let destinationData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                destinationData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                AppLogger.media.warning("Failed to create image destination for \(size.rawValue)")
                continue
            }

            let destinationProperties: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: size.jpegQuality,
            ]

            CGImageDestinationAddImage(destination, thumbnail, destinationProperties as CFDictionary)

            guard CGImageDestinationFinalize(destination) else {
                AppLogger.media.warning("Failed to finalize \(size.rawValue) image")
                continue
            }

            results[size] = destinationData as Data
        }

        guard !results.isEmpty else {
            throw ImageProcessingError.processingFailed
        }

        let originalKB = rawData.count / 1024
        let totalKB = results.values.reduce(0) { $0 + $1.count } / 1024
        AppLogger.media.info("Processed image: \(originalKB)KB → \(totalKB)KB (\(results.count) variants)")

        return results
    }
}

enum ImageProcessingError: LocalizedError {
    case invalidSourceData
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidSourceData:
            "The selected image could not be read."
        case .processingFailed:
            "The image could not be processed for upload."
        }
    }
}
