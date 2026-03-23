import Foundation

enum PhotoVideoMediaType: String, Codable, Hashable, CaseIterable, Identifiable {
    case photo
    case video
    case both

    var id: Self { self }

    var title: String {
        switch self {
        case .photo: "Photos"
        case .video: "Video"
        case .both: "Photo & Video"
        }
    }
}

struct PhotoVideoDetails: Codable, Hashable {
    var mediaType: PhotoVideoMediaType = .photo
    var deliverables: [String] = []
    var turnaroundNote: String = ""
    var secondShooterAvailable: Bool = false
    var droneAvailable: Bool = false

    var isEmpty: Bool {
        deliverables.isEmpty
            && turnaroundNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !secondShooterAvailable
            && !droneAvailable
    }

    static let photoDeliverableOptions = [
        "Digital gallery",
        "Prints",
        "Photo album",
        "Slideshow",
        "Raw files",
    ]

    static let videoDeliverableOptions = [
        "Highlight reel",
        "Full ceremony",
        "Reception edit",
        "Same-day edit",
        "Raw footage",
    ]
}
