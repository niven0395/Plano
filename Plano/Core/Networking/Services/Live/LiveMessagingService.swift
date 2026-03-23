import Foundation
#if canImport(Supabase)
import OSLog
import Supabase
import os.signpost

actor LiveMessagingService: MessagingServiceProtocol {
    private let client: SupabaseClient

    nonisolated(unsafe) private static let signpostLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "Plano",
        category: "messaging"
    )

    private static let iso8601Decoder: JSONDecoder = ISO8601Decoding.decoder

    /// Seconds before token expiry to trigger a proactive refresh.
    private static let tokenExpiryBuffer: TimeInterval = 30

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Ensures the session token is fresh, refreshing proactively if it will
    /// expire within `tokenExpiryBuffer` seconds.
    private func ensureFreshToken() async throws {
        let session = try await client.auth.session
        let expiresAt = Date(timeIntervalSince1970: session.expiresAt)
        let remaining = expiresAt.timeIntervalSinceNow
        print("[LiveMessaging] token expires in \(Int(remaining))s, user=\(session.user.id)")
        if remaining < Self.tokenExpiryBuffer {
            print("[LiveMessaging] proactive refresh (remaining \(Int(remaining))s < \(Int(Self.tokenExpiryBuffer))s)")
            do {
                _ = try await client.auth.refreshSession()
                print("[LiveMessaging] proactive refresh succeeded")
            } catch {
                print("[LiveMessaging] proactive refresh FAILED: \(error)")
                throw error
            }
        }
    }

    /// Invokes an edge function with automatic retry on 401.
    /// On a 401 response, refreshes the session and retries once.
    private func invokeWithAuth<T: Decodable>(
        _ functionName: String,
        options: FunctionInvokeOptions,
        decoder: JSONDecoder
    ) async throws -> T {
        try await ensureFreshToken()

        do {
            return try await client.functions.invoke(
                functionName,
                options: options,
                decoder: decoder
            )
        } catch let error as FunctionsError {
            switch error {
            case .httpError(let code, let data) where code == 401:
                let body = String(data: data, encoding: .utf8) ?? "<binary>"
                print("[LiveMessaging] \(functionName) got 401: \(body) — retrying after refresh")
                do {
                    _ = try await client.auth.refreshSession()
                    print("[LiveMessaging] retry refresh succeeded")
                } catch {
                    print("[LiveMessaging] retry refresh FAILED: \(error)")
                    throw error
                }

                do {
                    return try await client.functions.invoke(
                        functionName,
                        options: options,
                        decoder: decoder
                    )
                } catch {
                    throw mapFunctionError(error, functionName: functionName)
                }
            default:
                throw mapFunctionError(error, functionName: functionName)
            }
        } catch {
            throw error
        }
    }

    /// Invokes an edge function (discarding the response) with automatic retry on 401.
    private func invokeWithAuth(
        _ functionName: String,
        options: FunctionInvokeOptions
    ) async throws {
        try await ensureFreshToken()

        do {
            _ = try await client.functions.invoke(
                functionName,
                options: options
            )
        } catch let error as FunctionsError {
            switch error {
            case .httpError(let code, let data) where code == 401:
                let body = String(data: data, encoding: .utf8) ?? "<binary>"
                print("[LiveMessaging] \(functionName) got 401: \(body) — retrying after refresh")
                do {
                    _ = try await client.auth.refreshSession()
                } catch {
                    print("[LiveMessaging] retry refresh FAILED: \(error)")
                    throw error
                }

                do {
                    _ = try await client.functions.invoke(
                        functionName,
                        options: options
                    )
                } catch {
                    throw mapFunctionError(error, functionName: functionName)
                }
            default:
                throw mapFunctionError(error, functionName: functionName)
            }
        } catch {
            throw error
        }
    }

    private func mapFunctionError(_ error: Error, functionName: String) -> Error {
        guard let functionsError = error as? FunctionsError else {
            return error
        }

        switch functionsError {
        case .relayError:
            print("[LiveMessaging] \(functionName) relay error")
            return APIError.invalidResponse
        case .httpError(let code, let data):
            let message = EdgeFunctionErrorParser.userFacingMessage(from: data)
            let body = message ?? String(data: data, encoding: .utf8) ?? "<binary>"
            print("[LiveMessaging] \(functionName) failed with status \(code): \(body)")

            if let message {
                return APIError.notSupported(message)
            }

            return APIError.invalidResponse
        }
    }

    func fetchMessages(
        conversationID: UUID,
        before cursor: Date?,
        limit: Int
    ) async throws -> [MessageRecord] {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "FetchMessages", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.signpostLog, name: "FetchMessages", signpostID: signpostID) }

        let filterBuilder = client.from("messages")
            .select()
            .eq("conversation_id", value: conversationID)

        let finalQuery: PostgrestTransformBuilder
        if let cursor {
            finalQuery = filterBuilder
                .lt("created_at", value: Self.iso8601Formatter.string(from: cursor))
                .order("created_at", ascending: false)
                .limit(limit)
        } else {
            finalQuery = filterBuilder
                .order("created_at", ascending: false)
                .limit(limit)
        }

        let records: [MessageRecord] = try await finalQuery.execute().value
        return records.reversed()
    }

    func sendMessage(
        conversationID: UUID,
        body: String,
        kind: String,
        senderRole: String,
        clientID: UUID
    ) async throws -> MessageRecord {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "SendMessage", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.signpostLog, name: "SendMessage", signpostID: signpostID) }

        let payload = SendMessagePayload(
            conversationID: conversationID,
            body: body,
            kind: kind,
            clientID: clientID
        )

        let result: MessageRecord = try await invokeWithAuth(
            "send-message",
            options: FunctionInvokeOptions(body: payload),
            decoder: Self.iso8601Decoder
        )
        return result
    }

    func sendMessageWithAttachment(
        conversationID: UUID,
        body: String,
        kind: String,
        clientID: UUID,
        storagePath: String,
        fileName: String,
        mimeType: String,
        fileSizeBytes: Int64,
        width: Int?,
        height: Int?
    ) async throws -> MessageRecord {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "SendMessageWithAttachment", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.signpostLog, name: "SendMessageWithAttachment", signpostID: signpostID) }

        let payload = SendMessageWithAttachmentPayload(
            conversationID: conversationID,
            body: body,
            kind: kind,
            clientID: clientID,
            attachment: .init(
                storagePath: storagePath,
                fileName: fileName,
                mimeType: mimeType,
                fileSizeBytes: fileSizeBytes,
                width: width,
                height: height
            )
        )

        let result: MessageRecord = try await invokeWithAuth(
            "send-message-with-attachment",
            options: FunctionInvokeOptions(body: payload),
            decoder: Self.iso8601Decoder
        )
        return result
    }

    func markMessagesRead(conversationID: UUID, role: String) async throws {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "MarkRead", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.signpostLog, name: "MarkRead", signpostID: signpostID) }

        try await client.rpc(
            "mark_messages_read",
            params: [
                "p_conversation_id": AnyJSON.string(conversationID.uuidString),
                "p_role": AnyJSON.string(role),
            ]
        ).execute()
    }

    func uploadAttachment(
        data: Data,
        fileName: String,
        mimeType: String,
        userID: UUID
    ) async throws -> String {
        let signpostID = OSSignpostID(log: Self.signpostLog)
        os_signpost(.begin, log: Self.signpostLog, name: "UploadAttachment", signpostID: signpostID)
        defer { os_signpost(.end, log: Self.signpostLog, name: "UploadAttachment", signpostID: signpostID) }

        let path = "\(userID.uuidString)/\(UUID().uuidString)_\(fileName)"
        let bucket = client.storage.from("message-attachments")

        // Use signed upload URL for retry capability on large files.
        // If the upload fails mid-stream, we can retry with the same signed URL.
        do {
            let signedUpload = try await bucket.createSignedUploadURL(path: path)

            try await bucket.uploadToSignedURL(
                signedUpload.path,
                token: signedUpload.token,
                data: data,
                options: FileOptions(contentType: mimeType)
            )
        } catch {
            // Fallback to standard upload if signed upload isn't supported
            AppLogger.networking.warning("Signed upload failed, falling back to standard upload: \(error.localizedDescription, privacy: .public)")
            try await bucket.upload(
                path,
                data: data,
                options: FileOptions(contentType: mimeType)
            )
        }

        return path
    }

    func createAttachmentRecord(
        messageID: UUID,
        storagePath: String,
        fileName: String,
        mimeType: String,
        fileSizeBytes: Int64,
        width: Int?,
        height: Int?
    ) async throws -> MessageAttachmentRecord {
        let record = MessageAttachmentRecord(
            id: UUID(),
            messageID: messageID,
            storagePath: storagePath,
            fileName: fileName,
            mimeType: mimeType,
            fileSizeBytes: fileSizeBytes,
            width: width,
            height: height,
            thumbnailPath: nil,
            createdAt: .now
        )

        return try await client.from("message_attachments")
            .insert(record)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchAttachments(messageIDs: [UUID]) async throws -> [MessageAttachmentRecord] {
        guard !messageIDs.isEmpty else { return [] }

        return try await client.from("message_attachments")
            .select()
            .in("message_id", values: messageIDs)
            .order("created_at")
            .execute()
            .value
    }

    func markMessageDelivered(messageID: UUID) async throws {
        try await client.rpc(
            "mark_message_delivered",
            params: ["p_message_id": AnyJSON.string(messageID.uuidString)]
        ).execute()
    }

    func fetchMessagesSince(
        conversationID: UUID,
        after: Date,
        limit: Int
    ) async throws -> [MessageRecord] {
        let records: [MessageRecord] = try await client.from("messages")
            .select()
            .eq("conversation_id", value: conversationID)
            .gt("created_at", value: Self.iso8601Formatter.string(from: after))
            .order("created_at", ascending: true)
            .limit(limit)
            .execute()
            .value

        return records
    }

    func fetchMessagesSinceSequence(
        conversationID: UUID,
        afterSequence: Int,
        limit: Int
    ) async throws -> [MessageRecord] {
        let records: [MessageRecord] = try await client.from("messages")
            .select()
            .eq("conversation_id", value: conversationID)
            .gt("sequence_number", value: afterSequence)
            .order("sequence_number", ascending: true)
            .limit(limit)
            .execute()
            .value

        return records
    }

    func signedURL(for storagePath: String) async throws -> URL {
        try await client.storage
            .from("message-attachments")
            .createSignedURL(path: storagePath, expiresIn: 3600)
    }

    func registerDeviceToken(_ token: String, userID: UUID) async throws {
        let payload = RegisterDeviceTokenPayload(token: token, platform: "ios")
        try await invokeWithAuth(
            "register-device-token",
            options: FunctionInvokeOptions(body: payload)
        )
    }

    func removeDeviceToken(_ token: String, userID: UUID) async throws {
        try await client.from("device_tokens")
            .delete()
            .eq("user_id", value: userID)
            .eq("token", value: token)
            .execute()
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct SendMessagePayload: Encodable {
    let conversationID: UUID
    let body: String
    let kind: String
    let clientID: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case body
        case kind
        case clientID = "client_id"
    }
}

private struct SendMessageWithAttachmentPayload: Encodable {
    let conversationID: UUID
    let body: String
    let kind: String
    let clientID: UUID
    let attachment: AttachmentPayload

    struct AttachmentPayload: Encodable {
        let storagePath: String
        let fileName: String
        let mimeType: String
        let fileSizeBytes: Int64
        let width: Int?
        let height: Int?

        enum CodingKeys: String, CodingKey {
            case storagePath = "storage_path"
            case fileName = "file_name"
            case mimeType = "mime_type"
            case fileSizeBytes = "file_size_bytes"
            case width, height
        }
    }

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case body, kind
        case clientID = "client_id"
        case attachment
    }
}

private struct RegisterDeviceTokenPayload: Encodable {
    let token: String
    let platform: String
}
#else
actor LiveMessagingService: MessagingServiceProtocol {
    init(client: Any? = nil) {}

    func fetchMessages(conversationID: UUID, before cursor: Date?, limit: Int) async throws -> [MessageRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func sendMessage(conversationID: UUID, body: String, kind: String, senderRole: String, clientID: UUID) async throws -> MessageRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func sendMessageWithAttachment(conversationID: UUID, body: String, kind: String, clientID: UUID, storagePath: String, fileName: String, mimeType: String, fileSizeBytes: Int64, width: Int?, height: Int?) async throws -> MessageRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func markMessagesRead(conversationID: UUID, role: String) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func uploadAttachment(data: Data, fileName: String, mimeType: String, userID: UUID) async throws -> String {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func createAttachmentRecord(messageID: UUID, storagePath: String, fileName: String, mimeType: String, fileSizeBytes: Int64, width: Int?, height: Int?) async throws -> MessageAttachmentRecord {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func markMessageDelivered(messageID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchMessagesSince(conversationID: UUID, after: Date, limit: Int) async throws -> [MessageRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchMessagesSinceSequence(conversationID: UUID, afterSequence: Int, limit: Int) async throws -> [MessageRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func fetchAttachments(messageIDs: [UUID]) async throws -> [MessageAttachmentRecord] {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func signedURL(for storagePath: String) async throws -> URL {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func registerDeviceToken(_ token: String, userID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }

    func removeDeviceToken(_ token: String, userID: UUID) async throws {
        throw APIError.notSupported("The Supabase SDK is not available in this build.")
    }
}
#endif
