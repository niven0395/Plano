import Foundation
import Observation
import UIKit

enum ImageUploadState: Equatable {
    case processing
    case uploading(progress: Double)
    case complete
    case failed(String)

    var isInFlight: Bool {
        switch self {
        case .processing, .uploading:
            true
        case .complete, .failed:
            false
        }
    }
}

@MainActor
@Observable
final class ImageUploadProgress: Identifiable {
    let id = UUID()
    let localImage: UIImage
    var state: ImageUploadState = .processing
    var storagePath: String?

    init(localImage: UIImage) {
        self.localImage = localImage
    }
}
