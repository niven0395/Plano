import Foundation

enum EdgeFunctionErrorParser {
    nonisolated static func userFacingMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Try common error response shapes:
        // { "error": "message" }           — our edge functions
        // { "message": "message" }         — Supabase Auth / gateway
        // { "msg": "message" }             — PostgREST
        // { "error_description": "..." }   — OAuth
        let candidates: [String] = ["error", "message", "msg", "error_description"]
        for key in candidates {
            if let value = json[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }

        return nil
    }
}
