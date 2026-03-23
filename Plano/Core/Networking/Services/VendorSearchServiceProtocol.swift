import Foundation

protocol VendorSearchServiceProtocol {
    func searchVendors(matching request: VendorSearchRequest) async throws -> [VendorProfileRecord]
    func fetchSavedVendorIDs() async throws -> Set<UUID>
    func saveVendor(_ vendorID: UUID) async throws
    func unsaveVendor(_ vendorID: UUID) async throws
}
