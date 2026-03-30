import Foundation
#if canImport(Supabase)
import Supabase

actor LiveVendorProfileService: VendorProfileServiceProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func createVendorProfile(
        businessName: String,
        businessEmail: String?,
        category: VendorCategory,
        city: String?
    ) async throws -> VendorProfileRecord {
        let session = try await client.auth.session
        let record = VendorProfileRecord(
            userID: session.user.id,
            businessName: businessName,
            businessEmail: businessEmail,
            category: category.rawValue,
            city: city,
            profileCompleteness: 20,
            onboardedAt: .now
        )

        return try await upsertVendorProfile(record)
    }

    func fetchOwnVendorProfile() async throws -> VendorProfileRecord? {
        let session = try await client.auth.session
        return try await fetchProfile(userID: session.user.id)
    }

    func fetchPublicVendorProfile(vendorID: UUID) async throws -> VendorProfileRecord? {
        try await fetchProfile(userID: vendorID)
    }

    func updateVendorProfile(_ updates: VendorProfileRecord) async throws -> VendorProfileRecord {
        try await upsertVendorProfile(updates)
    }

    func fetchGalleryImages(vendorID: UUID) async throws -> [VendorGalleryImage] {
        let records: [VendorGalleryImageRecord] = try await client.from("vendor_gallery_images")
            .select()
            .eq("vendor_id", value: vendorID)
            .execute()
            .value

        return records
            .map { $0.makeImage() }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    func replaceGalleryImages(_ images: [VendorGalleryImage], vendorID: UUID) async throws {
        try await client.from("vendor_gallery_images")
            .delete()
            .eq("vendor_id", value: vendorID)
            .execute()

        guard !images.isEmpty else { return }

        let records = images.map { VendorGalleryImageRecord(image: $0, vendorID: vendorID) }
        try await client.from("vendor_gallery_images")
            .insert(records)
            .execute()
    }

    func fetchServiceItems(vendorID: UUID) async throws -> [VendorServiceItem] {
        let records: [VendorServiceItemRecord] = try await client.from("vendor_service_items")
            .select()
            .eq("vendor_id", value: vendorID)
            .execute()
            .value

        return records
            .map { $0.makeServiceItem() }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    func replaceServiceItems(_ items: [VendorServiceItem], vendorID: UUID) async throws {
        try await client.from("vendor_service_items")
            .delete()
            .eq("vendor_id", value: vendorID)
            .or("item_type.eq.service,item_type.is.null")
            .execute()

        guard !items.isEmpty else { return }

        let orderedItems = items.enumerated().map { index, item in
            VendorServiceItem(
                id: item.id,
                title: item.title,
                priceCents: item.priceCents,
                description: item.description,
                displayOrder: index
            )
        }
        let records = orderedItems.map { VendorServiceItemRecord(item: $0, vendorID: vendorID) }
        try await client.from("vendor_service_items")
            .insert(records)
            .execute()
    }

    func fetchPackages(vendorID: UUID) async throws -> [VendorPackage] {
        let records: [VendorPackageRecord] = try await client.from("vendor_packages")
            .select()
            .eq("vendor_id", value: vendorID)
            .execute()
            .value

        return records
            .map { $0.makePackage() }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    func replacePackages(_ packages: [VendorPackage], vendorID: UUID) async throws {
        try await client.from("vendor_packages")
            .delete()
            .eq("vendor_id", value: vendorID)
            .execute()

        guard !packages.isEmpty else { return }

        let records = packages.enumerated().map { index, pkg in
            VendorPackageRecord(
                package: VendorPackage(
                    id: pkg.id,
                    title: pkg.title,
                    priceCents: pkg.priceCents,
                    description: pkg.description,
                    includedItems: pkg.includedItems,
                    isHighlighted: pkg.isHighlighted,
                    pricingUnit: pkg.pricingUnit,
                    displayOrder: index
                ),
                vendorID: vendorID
            )
        }
        try await client.from("vendor_packages")
            .insert(records)
            .execute()
    }

    func fetchAddOns(vendorID: UUID) async throws -> [VendorAddOn] {
        let records: [VendorServiceItemRecord] = try await client.from("vendor_service_items")
            .select()
            .eq("vendor_id", value: vendorID)
            .eq("item_type", value: "addon")
            .execute()
            .value

        return records
            .map { $0.makeAddOn() }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    func replaceAddOns(_ addOns: [VendorAddOn], vendorID: UUID) async throws {
        try await client.from("vendor_service_items")
            .delete()
            .eq("vendor_id", value: vendorID)
            .eq("item_type", value: "addon")
            .execute()

        guard !addOns.isEmpty else { return }

        let records = addOns.enumerated().map { index, addOn in
            VendorServiceItemRecord(
                addOn: VendorAddOn(
                    id: addOn.id,
                    title: addOn.title,
                    priceCents: addOn.priceCents,
                    description: addOn.description,
                    displayOrder: index
                ),
                vendorID: vendorID
            )
        }
        try await client.from("vendor_service_items")
            .insert(records)
            .execute()
    }

    private func fetchProfile(userID: UUID) async throws -> VendorProfileRecord? {
        do {
            let record: VendorProfileRecord = try await client.from("vendor_profiles")
                .select()
                .eq("user_id", value: userID)
                .single()
                .execute()
                .value
            return record
        } catch {
            return nil
        }
    }

    func deleteVendorListing() async throws -> DeletionResult {
        try await client.rpc("delete_vendor_listing_with_cancellations")
            .execute()
            .value
    }

    private func upsertVendorProfile(_ record: VendorProfileRecord) async throws -> VendorProfileRecord {
        try await client.from("vendor_profiles")
            .upsert(record, onConflict: "user_id")
            .select()
            .single()
            .execute()
            .value
    }
}
#else
actor LiveVendorProfileService: VendorProfileServiceProtocol {
    init(client: Any? = nil) {}

    func createVendorProfile(
        businessName: String,
        businessEmail: String?,
        category: VendorCategory,
        city: String?
    ) async throws -> VendorProfileRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchOwnVendorProfile() async throws -> VendorProfileRecord? {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchPublicVendorProfile(vendorID: UUID) async throws -> VendorProfileRecord? {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func updateVendorProfile(_ updates: VendorProfileRecord) async throws -> VendorProfileRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchGalleryImages(vendorID: UUID) async throws -> [VendorGalleryImage] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func replaceGalleryImages(_ images: [VendorGalleryImage], vendorID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchServiceItems(vendorID: UUID) async throws -> [VendorServiceItem] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func replaceServiceItems(_ items: [VendorServiceItem], vendorID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchPackages(vendorID: UUID) async throws -> [VendorPackage] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func replacePackages(_ packages: [VendorPackage], vendorID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchAddOns(vendorID: UUID) async throws -> [VendorAddOn] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func replaceAddOns(_ addOns: [VendorAddOn], vendorID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func deleteVendorListing() async throws -> DeletionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }
}
#endif
