import Foundation
#if canImport(Supabase)
import Supabase

actor LiveVendorAvailabilityService: VendorAvailabilityServiceProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchAvailability(vendorID: UUID, from: Date, to: Date) async throws -> [VendorAvailabilityRecord] {
        try await client.from("vendor_availability")
            .select()
            .eq("vendor_id", value: vendorID)
            .gte("date", value: Self.dateFormatter.string(from: from))
            .lte("date", value: Self.dateFormatter.string(from: to))
            .order("date")
            .execute()
            .value
    }

    func setAvailability(vendorID: UUID, date: Date, status: String) async throws {
        let dateString = Self.dateFormatter.string(from: date)

        // Delete any existing non-booking row for this vendor+date first,
        // then insert. The old 2-column unique constraint was replaced with a
        // 3-column expression index that PostgREST can't target via onConflict.
        try await client.from("vendor_availability")
            .delete()
            .eq("vendor_id", value: vendorID)
            .eq("date", value: dateString)
            .is("booking_id", value: nil)
            .execute()

        let record = AvailabilityInsert(
            vendorID: vendorID,
            date: dateString,
            status: status
        )

        try await client.from("vendor_availability")
            .insert(record)
            .execute()
    }

    /// Write-only DTO matching the actual `vendor_availability` table columns.
    private struct AvailabilityInsert: Encodable {
        let vendorID: UUID
        let date: String
        let status: String

        enum CodingKeys: String, CodingKey {
            case vendorID = "vendor_id"
            case date
            case status
        }
    }

    func removeAvailability(vendorID: UUID, date: Date) async throws {
        try await client.from("vendor_availability")
            .delete()
            .eq("vendor_id", value: vendorID)
            .eq("date", value: Self.dateFormatter.string(from: date))
            .is("booking_id", value: nil)
            .execute()
    }

    func vendorsAvailable(on date: Date, category: VendorCategory?, city: String?) async throws -> [UUID] {
        let candidateRecords: [VendorProfileAvailabilityRecord]
        do {
            candidateRecords = try await fetchCandidateRecords(
                category: category,
                city: city,
                includeScheduleColumns: true
            )
        } catch {
            if Self.isMissingScheduleColumn(error) {
                candidateRecords = try await fetchCandidateRecords(
                    category: category,
                    city: city,
                    includeScheduleColumns: false
                )
            } else {
                throw error
            }
        }
        let candidateIDs = candidateRecords
            .filter { Self.isVendorBookable($0, on: date) }
            .map(\.userID)
        guard !candidateIDs.isEmpty else { return [] }

        let capacityByVendor = Dictionary(
            uniqueKeysWithValues: candidateRecords.map {
                ($0.userID, max($0.dailyEventCapacity ?? 1, 1))
            }
        )

        let bookedRecords: [VendorAvailabilityRecord] = try await client.from("vendor_availability")
            .select()
            .eq("date", value: Self.dateFormatter.string(from: date))
            .in("vendor_id", values: candidateIDs)
            .in("status", values: ["booked", "blocked", "hold"])
            .execute()
            .value

        let bookedCountByVendor = Dictionary(grouping: bookedRecords, by: \.vendorID)
            .mapValues { records in
                records.filter { $0.status == "booked" }.count
            }
        let blockedVendors = Set(bookedRecords.filter { $0.status == "blocked" }.map(\.vendorID))

        return candidateIDs.filter { vendorID in
            guard !blockedVendors.contains(vendorID) else { return false }
            let booked = bookedCountByVendor[vendorID] ?? 0
            let capacity = capacityByVendor[vendorID] ?? 1
            return booked < capacity
        }
    }

    func checkAvailability(vendorID: UUID, on date: Date) async throws -> VendorDateAvailability {
        let capacityRecords: [VendorProfileAvailabilityRecord] = try await client.from("vendor_profiles")
            .select("user_id,daily_event_capacity")
            .eq("user_id", value: vendorID)
            .execute()
            .value

        let capacity = max(capacityRecords.first?.dailyEventCapacity ?? 1, 1)

        let availabilityRecords: [VendorAvailabilityRecord] = try await client.from("vendor_availability")
            .select()
            .eq("vendor_id", value: vendorID)
            .eq("date", value: Self.dateFormatter.string(from: date))
            .execute()
            .value

        let isBlocked = availabilityRecords.contains { $0.status == "blocked" }
        let bookedCount = availabilityRecords.filter { $0.status == "booked" }.count

        return VendorDateAvailability(
            vendorID: vendorID,
            date: date,
            isAvailable: !isBlocked && bookedCount < capacity,
            bookedCount: bookedCount,
            capacity: capacity,
            checkedAt: .now
        )
    }

    func fetchTimeslotBookings(vendorID: UUID, from: Date, to: Date) async throws -> [VendorTimeslotBookingRecord] {
        try await client.from("vendor_timeslot_bookings")
            .select()
            .eq("vendor_id", value: vendorID)
            .gte("date", value: Self.dateFormatter.string(from: from))
            .lte("date", value: Self.dateFormatter.string(from: to))
            .order("date")
            .order("start_time")
            .execute()
            .value
    }

    func setTimeslotBooking(record: VendorTimeslotBookingRecord) async throws {
        try await client.from("vendor_timeslot_bookings")
            .upsert(record, onConflict: "vendor_id,date,start_time")
            .execute()
    }

    func removeTimeslotBooking(vendorID: UUID, date: Date, startTime: String) async throws {
        try await client.from("vendor_timeslot_bookings")
            .delete()
            .eq("vendor_id", value: vendorID)
            .eq("date", value: Self.dateFormatter.string(from: date))
            .eq("start_time", value: startTime)
            .execute()
    }

    private func fetchCandidateRecords(
        category: VendorCategory?,
        city: String?,
        includeScheduleColumns: Bool
    ) async throws -> [VendorProfileAvailabilityRecord] {
        _ = city
        let columns = includeScheduleColumns
            ? "user_id,available_days,lead_time_days,advance_booking_days,daily_event_capacity"
            : "user_id"
        var candidateQuery = client.from("vendor_profiles")
            .select(columns)

        if let category {
            candidateQuery = candidateQuery.eq("category", value: category.rawValue)
        }

        return try await candidateQuery.execute().value
    }

    nonisolated private static func isMissingScheduleColumn(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("available_days") ||
            description.contains("lead_time_days") ||
            description.contains("advance_booking_days")
    }

    nonisolated private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    nonisolated private static func isVendorBookable(_ record: VendorProfileAvailabilityRecord, on date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: .now)
        let leadTimeDays = min(max(record.leadTimeDays ?? 0, 0), 90)
        let advanceBookingDays = min(max(record.advanceBookingDays ?? 180, 7), 365)

        guard let earliestBookableDate = calendar.date(byAdding: .day, value: leadTimeDays, to: today),
              let latestBookableDate = calendar.date(byAdding: .day, value: advanceBookingDays, to: today),
              targetDate >= earliestBookableDate,
              targetDate <= latestBookableDate,
              let weekday = Weekday(date: targetDate) else {
            return false
        }

        let availableDays = Set((record.availableDays ?? Weekday.allCases.map(\.rawValue)).compactMap(Weekday.init(rawValue:)))
        return availableDays.contains(weekday)
    }
}

private struct VendorProfileAvailabilityRecord: Decodable {
    let userID: UUID
    let availableDays: [Int]?
    let leadTimeDays: Int?
    let advanceBookingDays: Int?
    let dailyEventCapacity: Int?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case availableDays = "available_days"
        case leadTimeDays = "lead_time_days"
        case advanceBookingDays = "advance_booking_days"
        case dailyEventCapacity = "daily_event_capacity"
    }
}
#else
actor LiveVendorAvailabilityService: VendorAvailabilityServiceProtocol {
    init(client: Any? = nil) {}

    func fetchAvailability(vendorID: UUID, from: Date, to: Date) async throws -> [VendorAvailabilityRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func setAvailability(vendorID: UUID, date: Date, status: String) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func removeAvailability(vendorID: UUID, date: Date) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func vendorsAvailable(on date: Date, category: VendorCategory?, city: String?) async throws -> [UUID] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func checkAvailability(vendorID: UUID, on date: Date) async throws -> VendorDateAvailability {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchTimeslotBookings(vendorID: UUID, from: Date, to: Date) async throws -> [VendorTimeslotBookingRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func setTimeslotBooking(record: VendorTimeslotBookingRecord) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func removeTimeslotBooking(vendorID: UUID, date: Date, startTime: String) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }
}
#endif
