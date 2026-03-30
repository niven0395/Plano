import Foundation

protocol VendorProfileServiceProtocol {
    func createVendorProfile(
        businessName: String,
        businessEmail: String?,
        category: VendorCategory,
        city: String?
    ) async throws -> VendorProfileRecord
    func fetchOwnVendorProfile() async throws -> VendorProfileRecord?
    func fetchPublicVendorProfile(vendorID: UUID) async throws -> VendorProfileRecord?
    func updateVendorProfile(_ updates: VendorProfileRecord) async throws -> VendorProfileRecord
    func fetchGalleryImages(vendorID: UUID) async throws -> [VendorGalleryImage]
    func replaceGalleryImages(_ images: [VendorGalleryImage], vendorID: UUID) async throws
    func fetchServiceItems(vendorID: UUID) async throws -> [VendorServiceItem]
    func replaceServiceItems(_ items: [VendorServiceItem], vendorID: UUID) async throws
    func fetchPackages(vendorID: UUID) async throws -> [VendorPackage]
    func replacePackages(_ packages: [VendorPackage], vendorID: UUID) async throws
    func fetchAddOns(vendorID: UUID) async throws -> [VendorAddOn]
    func replaceAddOns(_ addOns: [VendorAddOn], vendorID: UUID) async throws
    func deleteVendorListing() async throws -> DeletionResult
}
