import Foundation

enum ImageSize: String, CaseIterable, Sendable {
    case standard
    case thumbnail

    var maxDimension: CGFloat {
        switch self {
        case .standard: 1200
        case .thumbnail: 800
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .standard: 0.82
        case .thumbnail: 0.75
        }
    }

    var fileSuffix: String {
        switch self {
        case .standard: "_std"
        case .thumbnail: "_thumb"
        }
    }
}
