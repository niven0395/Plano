import Foundation

enum PostgresDateValueDecoder {
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601WithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let postgresTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX"
        return formatter
    }()

    private static let postgresTimestampWithoutFractionalSecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssXXXXX"
        return formatter
    }()

    private static let postgresDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func decodeIfPresent<Key: CodingKey>(
        forKey key: Key,
        from container: KeyedDecodingContainer<Key>
    ) throws -> Date? {
        guard container.contains(key), try !container.decodeNil(forKey: key) else {
            return nil
        }

        if let directDate = try? container.decode(Date.self, forKey: key) {
            return directDate
        }

        let value = try container.decode(String.self, forKey: key)
        if let date = parse(value) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Unsupported Postgres date value: \(value)"
        )
    }

    static func parse(_ value: String) -> Date? {
        if let date = iso8601WithFractionalSeconds.date(from: value) {
            return date
        }

        if let date = iso8601WithoutFractionalSeconds.date(from: value) {
            return date
        }

        if let date = postgresTimestampFormatter.date(from: value) {
            return date
        }

        if let date = postgresTimestampWithoutFractionalSecondsFormatter.date(from: value) {
            return date
        }

        if let date = postgresDateFormatter.date(from: value) {
            return date
        }

        return nil
    }
}
