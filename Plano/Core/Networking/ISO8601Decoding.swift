import Foundation

enum ISO8601Decoding {
    /// A `JSONDecoder` that handles both standard ISO 8601 dates and those
    /// with fractional seconds (as produced by PostgreSQL's `timestamptz`).
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let withFrac = ISO8601DateFormatter()
            withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFrac.date(from: string) { return date }

            let withoutFrac = ISO8601DateFormatter()
            withoutFrac.formatOptions = [.withInternetDateTime]
            if let date = withoutFrac.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode date string: \(string)"
            )
        }
        return decoder
    }()
}
