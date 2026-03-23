import Foundation

protocol PlannedVendorServiceProtocol: Sendable {
    func fetchPlannedVendors(eventID: UUID) async throws -> [PlannedVendorRecord]
    func fetchAllPlannedVendors(eventIDs: [UUID]) async throws -> [PlannedVendorRecord]
    func planVendor(eventID: UUID, vendorID: UUID, category: VendorCategory) async throws -> PlannedVendorRecord
    func removePlannedVendor(eventID: UUID, vendorID: UUID) async throws
    func updateStatus(eventID: UUID, vendorID: UUID, status: PlannedVendorStatus) async throws
    func batchUpdateStatus(eventID: UUID, vendorIDs: [UUID], status: PlannedVendorStatus) async throws
}
