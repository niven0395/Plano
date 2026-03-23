import Foundation
import Testing
@testable import Plano

struct EdgeFunctionErrorParserTests {
    @Test
    func extractsTrimmedMessageFromEdgeFunctionPayload() {
        let data = Data(#"{"error":"  Message rate limit exceeded  "}"#.utf8)

        #expect(EdgeFunctionErrorParser.userFacingMessage(from: data) == "Message rate limit exceeded")
    }

    @Test
    func returnsNilWhenPayloadIsMissingAnErrorMessage() {
        let data = Data(#"{"status":"bad request"}"#.utf8)

        #expect(EdgeFunctionErrorParser.userFacingMessage(from: data) == nil)
    }

    @Test
    func returnsNilForBlankErrorMessages() {
        let data = Data(#"{"error":"   "}"#.utf8)

        #expect(EdgeFunctionErrorParser.userFacingMessage(from: data) == nil)
    }
}
