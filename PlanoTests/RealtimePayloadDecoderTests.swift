import Foundation
import Testing
@testable import Plano

struct RealtimePayloadDecoderTests {
    @Test
    func decodesMessageRecordWithPostgresRealtimeTimestamp() throws {
        let data = Data(
            """
            {
              "id":"00000000-0000-0000-0000-00000000D001",
              "conversation_id":"00000000-0000-0000-0000-00000000C001",
              "sender_role":"host",
              "body":"Hey",
              "kind":"text",
              "created_at":"2026-03-15 18:46:46.731094+00",
              "status":"sent",
              "client_id":null
            }
            """.utf8
        )

        let record = try RealtimePayloadDecoder.makeJSONDecoder().decode(MessageRecord.self, from: data)

        #expect(record.senderRole == "host")
        #expect(record.body == "Hey")
    }

    @Test
    func decodesConversationRecordWithIso8601Timestamp() throws {
        let data = Data(
            """
            {
              "id":"00000000-0000-0000-0000-00000000C001",
              "event_id":null,
              "vendor_id":"00000000-0000-0000-0000-00000000A001",
              "host_id":"00000000-0000-0000-0000-00000000B001",
              "host_display_name":"Maya Chen",
              "vendor_display_name":"Studio Petal",
              "vendor_category":"decorator",
              "event_title":"Direct inquiry",
              "event_date_label":"Date pending",
              "event_context_line":"Guest count pending",
              "stage":"active",
              "last_activity_at":"2026-03-15T18:46:46.731Z",
              "created_at":null,
              "updated_at":null,
              "host_unread_count":1,
              "vendor_unread_count":0
            }
            """.utf8
        )

        let record = try RealtimePayloadDecoder.makeJSONDecoder().decode(ConversationRecord.self, from: data)

        #expect(record.hostDisplayName == "Maya Chen")
        #expect(record.hostUnreadCount == 1)
    }
}
