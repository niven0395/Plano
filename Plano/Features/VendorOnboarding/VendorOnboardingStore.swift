import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class VendorOnboardingStore {
    private let vendorProfileService: any VendorProfileServiceProtocol
    private let mediaService: any MediaServiceProtocol
    private let imageProcessor: ImageProcessor
    private let imageCache: ImageCache
    private let sessionStore: SessionStore

    // MARK: - Slide 1 (Required)

    var businessName = ""
    var businessEmail = ""
    var selectedCategory: VendorCategory = .decorator
    var city: GTACity = .toronto
    var profileImageData: Data?
    var profileImagePath: String?

    // MARK: - Slide 2 (About)

    var bio = ""
    var styleSummary = ""
    var serviceArea = ""

    // MARK: - Slide 3 (Category Details)

    var categoryDetails: CategoryDetails?

    // MARK: - Slide 4 (Gallery)

    var galleryImages: [VendorGalleryImage] = []
    var pendingUploads: [ImageUploadProgress] = []

    // MARK: - Slide 5 (Availability)

    var schedulePreset: SchedulePreset = .everyDay
    var availableDays: Set<Weekday> = Set(Weekday.allCases)
    var bookingMode: BookingMode = .inquiryOnly

    // MARK: - Navigation

    var currentSlide = 0
    var slideOneSubmitted = false
    var loadingState: LoadingState = .idle
    var lastSaveOutcome: SaveOutcome = .idle

    static let totalSlides = 5

    init(
        vendorProfileService: any VendorProfileServiceProtocol,
        mediaService: any MediaServiceProtocol,
        imageProcessor: ImageProcessor,
        imageCache: ImageCache,
        sessionStore: SessionStore
    ) {
        self.vendorProfileService = vendorProfileService
        self.mediaService = mediaService
        self.imageProcessor = imageProcessor
        self.imageCache = imageCache
        self.sessionStore = sessionStore
    }

    // MARK: - Validation

    var isSlideOneValid: Bool {
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isLastSlide: Bool {
        currentSlide == Self.totalSlides - 1
    }

    // MARK: - Navigation

    func advanceSlide() {
        guard currentSlide < Self.totalSlides - 1 else { return }
        currentSlide += 1
    }

    func goBack() {
        guard currentSlide > 0 else { return }
        currentSlide -= 1
    }

    func cancel() {
        sessionStore.requiresVendorOnboarding = false
    }

    func finishOnboarding() {
        sessionStore.requiresVendorOnboarding = false
    }

    // MARK: - Category Change

    func handleCategoryChange(to newCategory: VendorCategory) {
        categoryDetails = .empty(for: newCategory)
    }

    // MARK: - Slide 1: Submit

    func submitSlideOne() async {
        guard isSlideOneValid,
              let currentProfile = sessionStore.authenticatedProfile else {
            return
        }

        loadingState = .loading

        do {
            // Upload profile image if provided
            if let imageData = profileImageData {
                let variants = try await imageProcessor.processVariants(from: imageData)
                let path = try await mediaService.uploadImageVariants(variants, vendorID: currentProfile.userID)
                profileImagePath = path
                if let thumbData = variants[.thumbnail], let image = UIImage(data: thumbData) {
                    await imageCache.stageLocalImage(image, for: path)
                }
            }

            let trimmedEmail = businessEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            let record = try await vendorProfileService.createVendorProfile(
                businessName: businessName.trimmingCharacters(in: .whitespacesAndNewlines),
                businessEmail: trimmedEmail.isEmpty ? nil : trimmedEmail,
                category: selectedCategory,
                city: city.rawValue
            )

            // If profile image was uploaded, save it to the record
            if profileImagePath != nil {
                var updatedRecord = VendorProfileRecord(
                    userID: record.userID,
                    businessName: record.businessName,
                    businessEmail: record.businessEmail,
                    profileImagePath: profileImagePath,
                    category: record.category,
                    city: record.city,
                    profileCompleteness: record.profileCompleteness,
                    onboardedAt: record.onboardedAt
                )
                _ = try await vendorProfileService.updateVendorProfile(updatedRecord)
            }

            let updatedProfile = AuthenticatedUserProfile(
                userID: currentProfile.userID,
                emailAddress: currentProfile.emailAddress,
                displayName: currentProfile.displayName,
                vendorDisplayName: record.businessName
            )
            sessionStore.completeVendorOnboarding(with: updatedProfile)
            slideOneSubmitted = true
            loadingState = .loaded
            advanceSlide()
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Slides 2-5: Save & Continue

    func saveAndContinue() async {
        guard slideOneSubmitted,
              let userID = sessionStore.currentUserID else {
            advanceSlide()
            return
        }

        loadingState = .loading

        do {
            let record = makeUpdateRecord(userID: userID)
            _ = try await vendorProfileService.updateVendorProfile(record)

            // Save gallery images if on gallery slide
            if currentSlide == 3, !galleryImages.isEmpty {
                try await vendorProfileService.replaceGalleryImages(galleryImages, vendorID: userID)
            }

            loadingState = .loaded
            lastSaveOutcome = .saved

            if isLastSlide {
                finishOnboarding()
            } else {
                advanceSlide()
            }
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
            lastSaveOutcome = .failed(error.localizedDescription)
            // Still allow advancing on save failure
            if isLastSlide {
                finishOnboarding()
            } else {
                advanceSlide()
            }
        }
    }

    func skipCurrentSlide() {
        if isLastSlide {
            finishOnboarding()
        } else {
            advanceSlide()
        }
    }

    // MARK: - Profile Image

    func uploadProfileImage(data: Data) async {
        guard let userID = sessionStore.currentUserID ?? sessionStore.authenticatedProfile?.userID else { return }

        do {
            let variants = try await imageProcessor.processVariants(from: data)
            let path = try await mediaService.uploadImageVariants(variants, vendorID: userID)
            profileImagePath = path
            profileImageData = data

            if let thumbData = variants[.thumbnail], let image = UIImage(data: thumbData) {
                await imageCache.stageLocalImage(image, for: path)
            }
        } catch is CancellationError {
            // Normal task lifecycle
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    func removeProfileImage() {
        profileImagePath = nil
        profileImageData = nil
    }

    // MARK: - Gallery

    func addGalleryImage(data: Data) async {
        guard let userID = sessionStore.currentUserID else { return }
        guard galleryImages.count < 5 else { return }

        let localImage = UIImage(data: data)
        let progress = ImageUploadProgress(localImage: localImage ?? UIImage())
        pendingUploads.append(progress)

        do {
            progress.state = .processing
            let variants = try await imageProcessor.processVariants(from: data)

            progress.state = .uploading(progress: 0.5)
            let storagePath = try await mediaService.uploadImageVariants(variants, vendorID: userID)

            if let thumbData = variants[.thumbnail], let image = UIImage(data: thumbData) {
                await imageCache.stageLocalImage(image, for: storagePath)
            }

            galleryImages.append(
                VendorGalleryImage(
                    storagePath: storagePath,
                    displayOrder: galleryImages.count,
                    caption: "Portfolio image \(galleryImages.count + 1)"
                )
            )

            progress.storagePath = storagePath
            progress.state = .complete
            pendingUploads.removeAll { $0.id == progress.id }
        } catch is CancellationError {
            pendingUploads.removeAll { $0.id == progress.id }
        } catch {
            progress.state = .failed(error.localizedDescription)
        }
    }

    func removeGalleryImage(_ image: VendorGalleryImage) async {
        do {
            try await mediaService.deleteImage(path: image.storagePath)
        } catch is CancellationError {
            return
        } catch {
            // Continue with local removal even if storage delete fails
        }

        galleryImages.removeAll { $0.id == image.id }
        galleryImages = galleryImages.enumerated().map { index, item in
            VendorGalleryImage(
                id: item.id,
                storagePath: item.storagePath,
                displayOrder: index,
                caption: item.caption
            )
        }
    }

    // MARK: - Private

    private func makeUpdateRecord(userID: UUID) -> VendorProfileRecord {
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStyleSummary = styleSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedServiceArea = serviceArea.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = businessEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        let weeklySchedule = WeeklySchedule(preset: schedulePreset, availableDays: availableDays)

        return VendorProfileRecord(
            userID: userID,
            businessName: businessName.trimmingCharacters(in: .whitespacesAndNewlines),
            businessEmail: trimmedEmail.isEmpty ? nil : trimmedEmail,
            profileImagePath: profileImagePath,
            category: selectedCategory.rawValue,
            bio: trimmedBio.isEmpty ? nil : trimmedBio,
            styleSummary: trimmedStyleSummary.isEmpty ? nil : trimmedStyleSummary,
            city: city.rawValue,
            serviceArea: trimmedServiceArea.isEmpty ? nil : trimmedServiceArea,
            availableDays: weeklySchedule.availableDays.sorted().map(\.rawValue),
            schedulePreset: weeklySchedule.preset.rawValue,
            bookingMode: bookingMode.rawValue,
            categoryDetails: categoryDetails,
            onboardedAt: .now
        )
    }
}
