import Foundation

struct UnavailableAuthService: AuthServiceProtocol {
    let message: String

    func restoreSession() async throws -> RestoredAuthSession? {
        throw APIError.notConfigured(message)
    }

    func signInAnonymously() async throws -> AnonymousHostSession {
        throw APIError.notConfigured(message)
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        throw APIError.notConfigured(message)
    }

    func setHostIdentity(
        name: String,
        phone: String?,
        email: String?
    ) async throws -> AnonymousHostSession {
        throw APIError.notConfigured(message)
    }

    func upgradeAnonymousToApple(
        idToken: String,
        rawNonce: String,
        email: String?,
        givenName: String?,
        familyName: String?
    ) async throws -> AuthenticatedUserProfile {
        throw APIError.notConfigured(message)
    }

    func signUpWithEmail(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> EmailSignUpResult {
        throw APIError.notConfigured(message)
    }

    func resendEmailConfirmation(email: String) async throws {
        throw APIError.notConfigured(message)
    }

    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUserProfile {
        throw APIError.notConfigured(message)
    }

    func signOut() async throws {
        throw APIError.notConfigured(message)
    }

    func deleteAccount() async throws -> DeletionResult {
        throw APIError.notConfigured(message)
    }
}

struct UnavailableVendorSearchService: VendorSearchServiceProtocol {
    let message: String

    func searchVendors(matching request: VendorSearchRequest) async throws -> [VendorProfileRecord] {
        throw APIError.notConfigured(message)
    }

    func fetchSavedVendorIDs() async throws -> Set<UUID> {
        throw APIError.notConfigured(message)
    }

    func saveVendor(_ vendorID: UUID) async throws {
        throw APIError.notConfigured(message)
    }

    func unsaveVendor(_ vendorID: UUID) async throws {
        throw APIError.notConfigured(message)
    }
}

struct UnavailableVendorProfileService: VendorProfileServiceProtocol {
    let message: String

    func createVendorProfile(
        businessName: String,
        businessEmail: String?,
        category: VendorCategory,
        city: String?
    ) async throws -> VendorProfileRecord {
        throw APIError.notConfigured(message)
    }

    func fetchOwnVendorProfile() async throws -> VendorProfileRecord? {
        throw APIError.notConfigured(message)
    }

    func fetchPublicVendorProfile(vendorID: UUID) async throws -> VendorProfileRecord? {
        throw APIError.notConfigured(message)
    }

    func updateVendorProfile(_ updates: VendorProfileRecord) async throws -> VendorProfileRecord {
        throw APIError.notConfigured(message)
    }

    func fetchGalleryImages(vendorID: UUID) async throws -> [VendorGalleryImage] {
        throw APIError.notConfigured(message)
    }

    func replaceGalleryImages(_ images: [VendorGalleryImage], vendorID: UUID) async throws {
        throw APIError.notConfigured(message)
    }

    func fetchServiceItems(vendorID: UUID) async throws -> [VendorServiceItem] {
        throw APIError.notConfigured(message)
    }

    func replaceServiceItems(_ items: [VendorServiceItem], vendorID: UUID) async throws {
        throw APIError.notConfigured(message)
    }

    func fetchPackages(vendorID: UUID) async throws -> [VendorPackage] {
        throw APIError.notConfigured(message)
    }

    func replacePackages(_ packages: [VendorPackage], vendorID: UUID) async throws {
        throw APIError.notConfigured(message)
    }

    func fetchAddOns(vendorID: UUID) async throws -> [VendorAddOn] {
        throw APIError.notConfigured(message)
    }

    func replaceAddOns(_ addOns: [VendorAddOn], vendorID: UUID) async throws {
        throw APIError.notConfigured(message)
    }

    func deleteVendorListing() async throws -> DeletionResult {
        throw APIError.notConfigured(message)
    }
}

struct UnavailableMediaService: MediaServiceProtocol {
    let message: String

    func uploadImage(data: Data, vendorID: UUID) async throws -> String {
        throw APIError.notConfigured(message)
    }

    func uploadImageVariants(_ variants: [ImageSize: Data], vendorID: UUID) async throws -> String {
        throw APIError.notConfigured(message)
    }

    func deleteImage(path: String) async throws {
        throw APIError.notConfigured(message)
    }

    func imageURL(for path: String) async throws -> URL {
        throw APIError.notConfigured(message)
    }

    func imageURL(for path: String, size: ImageSize) async throws -> URL {
        throw APIError.notConfigured(message)
    }
}

struct UnavailableBookingService: BookingServiceProtocol {
    let message: String

    func fetchConversations(hostID: UUID) async throws -> [ConversationRecord] {
        throw APIError.notConfigured(message)
    }

    func fetchVendorConversations(vendorID: UUID) async throws -> [ConversationRecord] {
        throw APIError.notConfigured(message)
    }

    func createConversation(vendorID: UUID, hostID: UUID) async throws -> ConversationRecord {
        throw APIError.notConfigured(message)
    }

    func fetchMessages(conversationID: UUID) async throws -> [MessageRecord] {
        throw APIError.notConfigured(message)
    }

    func sendMessage(conversationID: UUID, body: String, kind: String, senderRole: String) async throws -> MessageRecord {
        throw APIError.notConfigured(message)
    }

    func fetchBookingRequests(conversationIDs: [UUID]) async throws -> [BookingRequestRecord] {
        throw APIError.notConfigured(message)
    }

    func fetchBookings(conversationIDs: [UUID]) async throws -> [BookingRecord] {
        throw APIError.notConfigured(message)
    }

    func fetchHostBookings(hostID: UUID) async throws -> [BookingRecord] {
        throw APIError.notConfigured(message)
    }

    func fetchVendorBookings(vendorID: UUID) async throws -> [BookingRecord] {
        throw APIError.notConfigured(message)
    }

    func submitBookingRequest(conversationID: UUID, eventDate: Date, note: String, requestedTimeStart: String?, requestedTimeEnd: String?, title: String?, budgetLabel: String?, guestCountLabel: String?, requestedServices: [String]?, intakeAnswers: [LeadIntakeAnswer]?, idempotencyKey: UUID) async throws -> BookingTransitionResult {
        throw APIError.notConfigured(message)
    }

    func acceptBooking(conversationID: UUID, idempotencyKey: UUID) async throws -> BookingTransitionResult {
        throw APIError.notConfigured(message)
    }

    func declineBooking(conversationID: UUID, reason: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult {
        throw APIError.notConfigured(message)
    }

    func requestPayment(conversationID: UUID, amountCents: Int, note: String?, paymentType: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult {
        throw APIError.notConfigured(message)
    }

    func confirmPayment(conversationID: UUID, idempotencyKey: UUID) async throws -> BookingTransitionResult {
        throw APIError.notConfigured(message)
    }

    func vendorConfirmPayment(conversationID: UUID, idempotencyKey: UUID) async throws -> BookingTransitionResult {
        throw APIError.notConfigured(message)
    }

    func cancelBooking(conversationID: UUID, reason: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult {
        throw APIError.notConfigured(message)
    }

    func respondToCancellationRequest(conversationID: UUID, approved: Bool, reason: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult {
        throw APIError.notConfigured(message)
    }

    func forceCancelBooking(conversationID: UUID, reason: String?, idempotencyKey: UUID) async throws -> BookingTransitionResult {
        throw APIError.notConfigured(message)
    }

    func checkVendorDateConflicts(vendorID: UUID, eventDate: Date) async throws -> [DateConflict] {
        throw APIError.notConfigured(message)
    }

    func createConversationServer(vendorID: UUID) async throws -> ConversationRecord {
        throw APIError.notConfigured(message)
    }

    func fetchConversationSummaries(role: String) async throws -> [ConversationSummaryRecord] {
        throw APIError.notConfigured(message)
    }

    func fetchVendorNote(conversationID: UUID) async throws -> String? {
        throw APIError.notConfigured(message)
    }

    func saveVendorNote(conversationID: UUID, content: String) async throws {
        throw APIError.notConfigured(message)
    }

    func fetchPendingExternalBookingRequests() async throws -> [ExternalBookingRequestRecord] {
        throw APIError.notConfigured(message)
    }

    func acceptExternalBookingRequest(requestID: UUID) async throws -> ExternalBookingAcceptResult {
        throw APIError.notConfigured(message)
    }

    func declineExternalBookingRequest(requestID: UUID, reason: String?) async throws {
        throw APIError.notConfigured(message)
    }
}

struct UnavailableVendorAvailabilityService: VendorAvailabilityServiceProtocol {
    let message: String

    func fetchAvailability(vendorID: UUID, from: Date, to: Date) async throws -> [VendorAvailabilityRecord] {
        throw APIError.notConfigured(message)
    }

    func setAvailability(vendorID: UUID, date: Date, status: String) async throws {
        throw APIError.notConfigured(message)
    }

    func removeAvailability(vendorID: UUID, date: Date) async throws {
        throw APIError.notConfigured(message)
    }

    func vendorsAvailable(on date: Date, category: VendorCategory?, city: String?) async throws -> [UUID] {
        throw APIError.notConfigured(message)
    }

    func checkAvailability(vendorID: UUID, on date: Date) async throws -> VendorDateAvailability {
        throw APIError.notConfigured(message)
    }

    func fetchTimeslotBookings(vendorID: UUID, from: Date, to: Date) async throws -> [VendorTimeslotBookingRecord] {
        throw APIError.notConfigured(message)
    }

    func setTimeslotBooking(record: VendorTimeslotBookingRecord) async throws {
        throw APIError.notConfigured(message)
    }

    func removeTimeslotBooking(vendorID: UUID, date: Date, startTime: String) async throws {
        throw APIError.notConfigured(message)
    }
}

struct UnavailableAnalyticsService: AnalyticsServiceProtocol {
    let message: String

    func track(_ event: AnalyticsEvent) {}

    func flush() async {}

    func fetchInsights(period: InsightsPeriod) async throws -> VendorInsightsRecord {
        throw APIError.notConfigured(message)
    }
}

struct UnavailableMessagingService: MessagingServiceProtocol {
    let message: String

    func fetchMessages(conversationID: UUID, beforeSequence: Int?, limit: Int) async throws -> [MessageRecord] {
        throw APIError.notConfigured(message)
    }

    func sendMessage(conversationID: UUID, body: String, kind: String, senderRole: String, clientID: UUID) async throws -> MessageRecord {
        throw APIError.notConfigured(message)
    }

    func markMessagesRead(conversationID: UUID, role: String) async throws {
        throw APIError.notConfigured(message)
    }

    func uploadAttachment(data: Data, fileName: String, mimeType: String, userID: UUID) async throws -> String {
        throw APIError.notConfigured(message)
    }

    func createAttachmentRecord(messageID: UUID, storagePath: String, fileName: String, mimeType: String, fileSizeBytes: Int64, width: Int?, height: Int?) async throws -> MessageAttachmentRecord {
        throw APIError.notConfigured(message)
    }

    func fetchAttachments(messageIDs: [UUID]) async throws -> [MessageAttachmentRecord] {
        throw APIError.notConfigured(message)
    }

    func signedURL(for storagePath: String) async throws -> URL {
        throw APIError.notConfigured(message)
    }

    func markMessageDelivered(messageID: UUID) async throws {
        throw APIError.notConfigured(message)
    }

    func fetchMessagesSinceSequence(conversationID: UUID, afterSequence: Int, limit: Int) async throws -> [MessageRecord] {
        throw APIError.notConfigured(message)
    }

    func fetchMessagesSince(conversationID: UUID, after: Date, limit: Int) async throws -> [MessageRecord] {
        throw APIError.notConfigured(message)
    }

    func registerDeviceToken(_ token: String, userID: UUID) async throws {
        throw APIError.notConfigured(message)
    }

    func removeDeviceToken(_ token: String, userID: UUID) async throws {
        throw APIError.notConfigured(message)
    }

    func sendMessageWithAttachments(conversationID: UUID, body: String, kind: String, clientID: UUID, attachments: [MessageAttachmentUpload]) async throws -> MessageSendResult {
        throw APIError.notConfigured(message)
    }
}
