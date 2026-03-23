import Foundation

enum RealtimePayloadDecoder {
    nonisolated static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let withFractionalSeconds = ISO8601DateFormatter()
            withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractionalSeconds.date(from: string) {
                return date
            }

            let withoutFractionalSeconds = ISO8601DateFormatter()
            withoutFractionalSeconds.formatOptions = [.withInternetDateTime]
            if let date = withoutFractionalSeconds.date(from: string) {
                return date
            }

            let postgresTimestampFormatter = DateFormatter()
            postgresTimestampFormatter.calendar = Calendar(identifier: .gregorian)
            postgresTimestampFormatter.locale = Locale(identifier: "en_US_POSIX")
            postgresTimestampFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            postgresTimestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX"
            if let date = postgresTimestampFormatter.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode realtime date string: \(string)"
            )
        }
        return decoder
    }
}
