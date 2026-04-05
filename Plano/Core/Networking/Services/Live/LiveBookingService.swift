import Foundation
#if canImport(Supabase)
import OSLog
import Supabase
import os.signpost

actor LiveBookingService: BookingServiceProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchConversations(hostID: UUID) async throws -> [ConversationRecord] {
        let sessionUserID = try await sessionUserID(expected: hostID, action: "fetchConversations")
        return try await client.from("conversations")
            .select()
            .eq("host_id", value: sessionUserID)
            .order("last_activity_at", ascending: false)
            .execute()
            .value
    }

    func fetchVendorConversations(vendorID: UUID) async throws -> [ConversationRecord] {
        let sessionUserID = try await sessionUserID(expected: vendorID, action: "fetchVendorConversations")
        return try await client.from("conversations")
            .select()
            .eq("vendor_id", value: sessionUserID)
            .order("last_activity_at", ascending: false)
            .execute()
            .value
    }

    func createConversation(vendorID: UUID, hostID: UUID) async throws -> ConversationRecord {
        _ = try await sessionUserID(expected: hostID, action: "createConversation")
        return try await createConversationServer(vendorID: vendorID)
    }

    func fetchMessages(conversationID: UUID) async throws -> [MessageRecord] {
        try await client.from("messages")
            .select()
            .eq("conversation_id", value: conversationID)
            .order("created_at")
            .execute()
            .value
    }

    func sendMessage(conversationID: UUID, body: String, kind: String, senderRole: String) async throws -> MessageRecord {
        let message = MessageRecord(
            id: UUID(),
            conversationID: conversationID,
            senderRole: senderRole,
            body: body,
            kind: kind,
            createdAt: .now
        )

        let createdMessage: MessageRecord = try await client.from("messages")
            .insert(message)
            .select()
            .single()
            .execute()
            .value

        try await client.from("conversations")
            .update([
                "last_activity_at": Self.makeISO8601DateTimeFormatter().string(from: createdMessage.createdAt),
            ])
            .eq("id", value: conversationID)
            .execute()

        return createdMessage
    }

    func fetchBookingRequests(conversationIDs: [UUID]) async throws -> [BookingRequestRecord] {
        guard !conversationIDs.isEmpty else { return [] }

        return try await client.from("booking_requests")
            .select()
            .in("conversation_id", values: conversationIDs)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchBookings(conversationIDs: [UUID]) async throws -> [BookingRecord] {
        guard !conversationIDs.isEmpty else { return [] }

        return try await client.from("bookings")
            .select()
            .in("conversation_id", values: conversationIDs)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchHostBookings(hostID: UUID) async throws -> [BookingRecord] {
        let sessionUserID = try await sessionUserID(expected: hostID, action: "fetchHostBookings")
        return try await client.from("bookings")
            .select()
            .eq("host_id", value: sessionUserID)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchVendorBookings(vendorID: UUID) async throws -> [BookingRecord] {
        let sessionUserID = try await sessionUserID(expected: vendorID, action: "fetchVendorBookings")
        return try await client.from("bookings")
            .select()
            .eq("vendor_id", value: sessionUserID)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func submitBookingRequest(conversationID: UUID, eventDate: Date, note: String, requestedTimeStart: String?, requestedTimeEnd: String?, title: String?, budgetLabel: String?, guestCountLabel: String?, requestedServices: [String]?, intakeAnswers: [LeadIntakeAnswer]?) async throws -> BookingTransitionResult {
        try await invokeFunction(
            "submit-booking-v2",
            body: SubmitBookingRequestV2Payload(
                conversationID: conversationID,
                eventDate: Self.makeDateOnlyFormatter().string(from: eventDate),
                note: note,
                requestedTimeStart: requestedTimeStart,
                requestedTimeEnd: requestedTimeEnd,
                idempotencyKey: UUID(),
                title: title,
                budgetLabel: budgetLabel,
                guestCountLabel: guestCountLabel,
                requestedServices: requestedServices,
                intakeAnswers: intakeAnswers
            )
        )
    }

    func acceptBooking(conversationID: UUID) async throws -> BookingTransitionResult {
        try await invokeFunction(
            "accept-booking",
            body: AcceptBookingPayload(conversationID: conversationID, idempotencyKey: UUID())
        )
    }

    func declineBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult {
        try await invokeFunction(
            "decline-booking",
            body: DeclineBookingPayload(conversationID: conversationID, reason: reason, idempotencyKey: UUID())
        )
    }

    func requestPayment(conversationID: UUID, amountCents: Int, note: String?, paymentType: String?) async throws -> BookingTransitionResult {
        try await invokeFunction(
            "request-payment",
            body: RequestPaymentPayload(conversationID: conversationID, amountCents: amountCents, note: note, paymentType: paymentType, idempotencyKey: UUID())
        )
    }

    func confirmPayment(conversationID: UUID) async throws -> BookingTransitionResult {
        try await invokeFunction(
            "confirm-payment",
            body: ConfirmPaymentPayload(conversationID: conversationID, idempotencyKey: UUID())
        )
    }

    func vendorConfirmPayment(conversationID: UUID) async throws -> BookingTransitionResult {
        try await invokeFunction(
            "vendor-confirm-payment",
            body: VendorConfirmPaymentPayload(conversationID: conversationID, idempotencyKey: UUID())
        )
    }

    func cancelBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult {
        try await invokeFunction(
            "cancel-booking",
            body: CancelBookingPayload(
                conversationID: conversationID,
                reason: reason,
                idempotencyKey: UUID()
            )
        )
    }

    func respondToCancellationRequest(conversationID: UUID, approved: Bool, reason: String?) async throws -> BookingTransitionResult {
        try await invokeFunction(
            "respond-to-cancellation-request",
            body: RespondToCancellationPayload(
                conversationID: conversationID,
                approved: approved,
                reason: reason,
                idempotencyKey: UUID()
            )
        )
    }

    func forceCancelBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult {
        try await invokeFunction(
            "force-cancel-booking",
            body: CancelBookingPayload(
                conversationID: conversationID,
                reason: reason,
                idempotencyKey: UUID()
            )
        )
    }

    func checkVendorDateConflicts(vendorID: UUID, eventDate: Date) async throws -> [DateConflict] {
        let response: DateConflictEnvelope = try await invokeFunction(
            "check-vendor-date-conflicts",
            body: CheckVendorDateConflictsPayload(
                vendorID: vendorID,
                eventDate: Self.makeDateOnlyFormatter().string(from: eventDate)
            )
        )
        return response.conflicts
    }

    func createConversationServer(vendorID: UUID) async throws -> ConversationRecord {
        try await invokeFunction(
            "create-conversation-server",
            body: CreateConversationServerPayload(vendorID: vendorID)
        )
    }

    func fetchConversationSummaries(role: String) async throws -> [ConversationSummaryRecord] {
        try await invokeFunction(
            "fetch-booking-summary",
            body: FetchBookingSummaryPayload(role: role)
        )
    }

    func fetchVendorNote(conversationID: UUID) async throws -> String? {
        try await ensureFreshToken()
        let session = try await client.auth.session
        struct NoteRow: Decodable { let content: String }
        do {
            let row: NoteRow = try await client.from("vendor_notes")
                .select("content")
                .eq("conversation_id", value: conversationID)
                .eq("vendor_id", value: session.user.id)
                .single()
                .execute()
                .value
            return row.content
        } catch {
            return nil
        }
    }

    func saveVendorNote(conversationID: UUID, content: String) async throws {
        try await ensureFreshToken()
        let session = try await client.auth.session
        try await client.from("vendor_notes")
            .upsert([
                "conversation_id": conversationID.uuidString,
                "vendor_id": session.user.id.uuidString,
                "content": content,
                "updated_at": ISO8601DateFormatter().string(from: .now),
            ])
            .execute()
    }

    private func fetchOptionalRecord<Record: Decodable>(
        from table: String,
        matching column: String,
        value: UUID
    ) async throws -> Record? {
        do {
            return try await client.from(table)
                .select()
                .eq(column, value: value)
                .single()
                .execute()
                .value
        } catch {
            return nil
        }
    }

    /// Seconds before token expiry to trigger a proactive refresh.
    private static let tokenExpiryBuffer: TimeInterval = 30

    private func ensureFreshToken() async throws {
        let session = try await client.auth.session
        let expiresAt = Date(timeIntervalSince1970: session.expiresAt)
        if expiresAt.timeIntervalSinceNow < Self.tokenExpiryBuffer {
            _ = try await client.auth.refreshSession()
        }
    }

    private func sessionUserID(expected suppliedUserID: UUID, action: StaticString) async throws -> UUID {
        try await ensureFreshToken()
        let session = try await client.auth.session
        let activeUserID = session.user.id

        if suppliedUserID != activeUserID {
            AppLogger.booking.error(
                "Ignoring supplied user ID \(suppliedUserID.uuidString, privacy: .public) for \(String(describing: action), privacy: .public); active session is \(activeUserID.uuidString, privacy: .public)"
            )
        }

        return activeUserID
    }

    private func invokeFunction<Response: Decodable, Body: Encodable>(
        _ name: StaticString,
        body: Body,
        decoder: JSONDecoder = ISO8601Decoding.decoder
    ) async throws -> Response {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "EdgeFunctionInvoke", signpostID: signpostID, "%{public}s", "\(name)")
        defer {
            os_signpost(.end, log: Self.signpostLog, name: "EdgeFunctionInvoke", signpostID: signpostID, "%{public}s", "\(name)")
        }

        try await ensureFreshToken()

        let options = FunctionInvokeOptions(body: body)

        do {
            return try await client.functions.invoke(
                "\(name)",
                options: options,
                decoder: decoder
            )
        } catch let error as FunctionsError {
            if case .httpError(let code, _) = error, code == 401 {
                _ = try await client.auth.refreshSession()
                do {
                    return try await client.functions.invoke(
                        "\(name)",
                        options: options,
                        decoder: decoder
                    )
                } catch {
                    throw mapFunctionError(error)
                }
            }
            throw mapFunctionError(error)
        } catch {
            throw mapFunctionError(error)
        }
    }

    private func mapFunctionError(_ error: Error) -> Error {
        if let decodingError = error as? DecodingError {
            let detail: String
            switch decodingError {
            case .typeMismatch(let type, let context):
                detail = "Expected \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .keyNotFound(let key, _):
                detail = "Missing key: \(key.stringValue)"
            case .valueNotFound(let type, let context):
                detail = "Null value for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .dataCorrupted(let context):
                detail = "Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
            @unknown default:
                detail = String(describing: decodingError)
            }
            AppLogger.booking.error("Edge function decode failed: \(detail, privacy: .public)")
            return APIError.notSupported("The server response could not be decoded. Please try again.")
        }

        guard let functionsError = error as? FunctionsError else {
            return error
        }

        switch functionsError {
        case .relayError:
            AppLogger.booking.error("Edge function relay error")
            return APIError.notSupported("The server could not process this request. Please try again.")
        case .httpError(let code, let data):
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            AppLogger.booking.error("Edge function HTTP \(code): \(bodyPreview, privacy: .public)")
            if let message = EdgeFunctionErrorParser.userFacingMessage(from: data) {
                return APIError.notSupported(message)
            }
            return APIError.notSupported("Request failed (HTTP \(code)). Please try again.")
        }
    }

    nonisolated(unsafe) private static let signpostLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "Plano",
        category: "booking.edge"
    )

    private static func makeISO8601DateTimeFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func makeDateOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

private struct CreateConversationServerPayload: Encodable {
    let vendorID: UUID

    enum CodingKeys: String, CodingKey {
        case vendorID = "vendor_id"
    }
}

private struct FetchBookingSummaryPayload: Encodable {
    let role: String
}
#else
actor LiveBookingService: BookingServiceProtocol {
    init(client: Any? = nil) {}

    func fetchConversations(hostID: UUID) async throws -> [ConversationRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchVendorConversations(vendorID: UUID) async throws -> [ConversationRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func createConversation(vendorID: UUID, hostID: UUID) async throws -> ConversationRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchMessages(conversationID: UUID) async throws -> [MessageRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func sendMessage(conversationID: UUID, body: String, kind: String, senderRole: String) async throws -> MessageRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchBookingRequests(conversationIDs: [UUID]) async throws -> [BookingRequestRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchBookings(conversationIDs: [UUID]) async throws -> [BookingRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchHostBookings(hostID: UUID) async throws -> [BookingRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchVendorBookings(vendorID: UUID) async throws -> [BookingRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func submitBookingRequest(conversationID: UUID, eventDate: Date, note: String, requestedTimeStart: String?, requestedTimeEnd: String?, title: String?, budgetLabel: String?, guestCountLabel: String?, requestedServices: [String]?) async throws -> BookingTransitionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func acceptBooking(conversationID: UUID) async throws -> BookingTransitionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func declineBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func requestPayment(conversationID: UUID, amountCents: Int, note: String?, paymentType: String?) async throws -> BookingTransitionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func confirmPayment(conversationID: UUID) async throws -> BookingTransitionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func vendorConfirmPayment(conversationID: UUID) async throws -> BookingTransitionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func cancelBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func respondToCancellationRequest(conversationID: UUID, approved: Bool, reason: String?) async throws -> BookingTransitionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func forceCancelBooking(conversationID: UUID, reason: String?) async throws -> BookingTransitionResult {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func checkVendorDateConflicts(vendorID: UUID, eventDate: Date) async throws -> [DateConflict] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func createConversationServer(vendorID: UUID) async throws -> ConversationRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchConversationSummaries(role: String) async throws -> [ConversationSummaryRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

}
#endif
