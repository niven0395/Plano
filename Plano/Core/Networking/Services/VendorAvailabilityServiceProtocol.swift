import Foundation

protocol VendorAvailabilityServiceProtocol: Sendable {
    func fetchAvailability(vendorID: UUID, from: Date, to: Date) async throws -> [VendorAvailabilityRecord]
    func setAvailability(vendorID: UUID, date: Date, status: String) async throws
    func removeAvailability(vendorID: UUID, date: Date) async throws
    func vendorsAvailable(on date: Date, category: VendorCategory?, city: String?) async throws -> [UUID]
    func checkAvailability(vendorID: UUID, on date: Date) async throws -> VendorDateAvailability
    func fetchTimeslotBookings(vendorID: UUID, from: Date, to: Date) async throws -> [VendorTimeslotBookingRecord]
    func setTimeslotBooking(record: VendorTimeslotBookingRecord) async throws
    func removeTimeslotBooking(vendorID: UUID, date: Date, startTime: String) async throws
}

struct VendorDateAvailability: Sendable {
    let vendorID: UUID
    let date: Date
    let isAvailable: Bool
    let bookedCount: Int
    let capacity: Int
    let checkedAt: Date

    var remainingCapacity: Int { max(capacity - bookedCount, 0) }
}
