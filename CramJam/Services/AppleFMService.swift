import Foundation
import FoundationModels

final class AppleFMService {
    static let shared = AppleFMService()

    static var isAvailable: Bool {
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
            return false
        }
        return false
    }

    func outlineDraft(sentences: [String], language: String) async -> StudyNote? {
        guard #available(iOS 26, *), Self.isAvailable, !sentences.isEmpty else { return nil }
        do {
            let session = LanguageModelSession()
            let transcript = sentences.prefix(80).enumerated().map { "[\($0.offset)] \($0.element)" }.joined(separator: "\n")
            let prompt = """
            Create an outline study note from this lecture transcript. Respond with strict JSON only: {"note":{"title":"","headings":[{"heading":"","bullets":[""],"source_sentence_ids":[0]}],"key_terms":[{"term":"","definition":""}],"summary":""}}. At least 3 headings, source_sentence_ids reference the bracketed indices, summary at most 5 sentences, write in \(language).
            \(transcript)
            """
            let response = try await session.respond(to: prompt)
            guard let start = response.content.firstIndex(of: "{"),
                  let end = response.content.lastIndex(of: "}") else { return nil }
            let json = String(response.content[start...end])
            guard let data = json.data(using: .utf8),
                  let result = try? JSONDecoder().decode(StudyResult.self, from: data) else { return nil }
            return result.note
        } catch {
            return nil
        }
    }
}
