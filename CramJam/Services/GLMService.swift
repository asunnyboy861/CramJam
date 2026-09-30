import Foundation

final class GLMService: ObservableObject {
    static let shared = GLMService()

    static let devKey = "cramjam-dev-2026" // TODO(production): replace devKey with appTransaction JWS validation
    static let appId = "cramjam" // Worker-side rate-limit namespace (30/hour + 200/day per appId:userId)
    static let workerURL = URL(string: "https://cramjam-api.calcs.top")!
    static let byoURL = URL(string: "https://api.z.ai/api/paas/v4/chat/completions")!
    static let model = "glm-5.3-flash"

    enum GLMError: LocalizedError {
        case insufficientCredits
        case rateLimited
        case unauthorized
        case server(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .insufficientCredits:
                return "Cloud credits are used up. Notes were generated on-device instead."
            case .rateLimited:
                return "Too many cloud requests right now. Please try again later — notes were generated on-device instead."
            case .unauthorized:
                return "Cloud request was rejected. Notes were generated on-device instead."
            case .server(let message):
                return message
            case .badResponse:
                return "Cloud response was malformed. Notes were generated on-device instead."
            }
        }
    }

    @Published var creditsBalance: Int?
    @Published var lastRouteWasOnDevice = false

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 180
        session = URLSession(configuration: config)
    }

    func complete(messages: [[String: Any]], maxTokens: Int) async throws -> String {
        let payload: [String: Any] = [
            "model": Self.model,
            "messages": messages,
            "thinking": ["level": "low"],
            "max_tokens": maxTokens,
            "response_format": ["type": "json_object"],
            "temperature": 0.3
        ]
        let byoKey = KeychainHelper.glmKey
        do {
            let content: String
            if byoKey.isEmpty {
                content = try await sendWorker(payload)
            } else {
                content = try await sendDirect(payload, key: byoKey)
            }
            lastRouteWasOnDevice = false
            return content
        } catch {
            throw error
        }
    }

    private func sendWorker(_ payload: [String: Any]) async throws -> String {
        let envelope: [String: Any] = [
            "appId": Self.appId,
            "userId": KeychainHelper.userUUID,
            "payload": payload,
            "devKey": Self.devKey
        ]
        var request = URLRequest(url: Self.workerURL, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: envelope)
        let (data, response) = try await executeWithRetry(request)
        guard let http = response as? HTTPURLResponse else { throw GLMError.badResponse }
        switch http.statusCode {
        case 200:
            return try parseContent(data)
        case 401:
            throw GLMError.unauthorized
        case 402:
            updateCredits(from: data)
            throw GLMError.insufficientCredits
        case 429:
            throw GLMError.rateLimited
        default:
            throw GLMError.server("Cloud service error (\(http.statusCode)).")
        }
    }

    private func sendDirect(_ payload: [String: Any], key: String) async throws -> String {
        var request = URLRequest(url: Self.byoURL, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await executeWithRetry(request)
        guard let http = response as? HTTPURLResponse else { throw GLMError.badResponse }
        switch http.statusCode {
        case 200:
            return try parseContent(data)
        case 401:
            throw GLMError.unauthorized
        case 402:
            throw GLMError.insufficientCredits
        default:
            throw GLMError.server("Your key was rejected (\(http.statusCode)).")
        }
    }

    private func executeWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error = GLMError.badResponse
        for attempt in 0..<2 {
            do {
                return try await session.data(for: request)
            } catch {
                lastError = error
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                }
            }
        }
        throw lastError
    }

    private struct OpenAIEnvelope: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                var content: String?
            }
            var message: Message?
        }
        var choices: [Choice]?
        var creditsRemaining: Int?
        var remainingCredits: Int?
        var credits: Int?
        var balance: Int?

        enum CodingKeys: String, CodingKey {
            case choices, credits, balance
            case creditsRemaining = "credits_remaining"
            case remainingCredits = "remaining_credits"
        }
    }

    private func parseContent(_ data: Data) throws -> String {
        let decoded = try? JSONDecoder().decode(OpenAIEnvelope.self, from: data)
        updateCredits(from: data)
        guard let content = decoded?.choices?.first?.message?.content, !content.isEmpty else {
            throw GLMError.badResponse
        }
        return content
    }

    private func updateCredits(from data: Data) {
        guard let decoded = try? JSONDecoder().decode(OpenAIEnvelope.self, from: data) else { return }
        let candidates = [decoded.creditsRemaining, decoded.remainingCredits, decoded.credits, decoded.balance].compactMap { $0 }
        if let value = candidates.first {
            DispatchQueue.main.async { self.creditsBalance = value }
        }
    }

    static func textMessage(role: String, content: String) -> [String: Any] {
        ["role": role, "content": content]
    }

    static func visionMessage(text: String, imageDataURL: String) -> [String: Any] {
        [
            "role": "user",
            "content": [
                ["type": "text", "text": text],
                ["type": "image_url", "image_url": ["url": imageDataURL]]
            ]
        ]
    }
}

extension GLMService {
    func generateStudyResult(sentences: [(index: Int, text: String)], glossary: [String: String], language: String) async throws -> StudyResult {
        var transcriptLines = sentences.prefix(120).map { "[\($0.index)] \($0.text)" }
        if sentences.count > 120 {
            transcriptLines.append("[\(sentences.count - 1)] \(sentences.last!.text)")
        }
        let glossaryBlock = glossary.isEmpty ? "None" : glossary.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        let system = """
        You are a study-notes engine for college lectures. Respond with strict JSON only, no markdown. Schema: {"note":{"title":"","headings":[{"heading":"","bullets":[""],"source_sentence_ids":[0]}],"key_terms":[{"term":"","definition":""}],"summary":""},"flashcards":[{"question":"","answer":"","tag":""}],"quiz":[{"question":"","options":["a","b","c","d"],"answer_index":0,"explanation":""}]}. Rules: summary at most 5 sentences; at most 20 flashcards; at most 5 quiz items with exactly 4 options each; source_sentence_ids must reference the bracketed transcript indices; headings at least 3; write everything in \(language).
        """
        let user = """
        Lecture transcript (numbered sentences):
        \(transcriptLines.joined(separator: "\n"))

        Course glossary (canonical terms — use these exact spellings):
        \(glossaryBlock)
        """
        let content = try await complete(
            messages: [Self.textMessage(role: "system", content: system), Self.textMessage(role: "user", content: user)],
            maxTokens: 4096
        )
        guard let data = content.data(using: .utf8),
              let result = try? JSONDecoder().decode(StudyResult.self, from: data) else {
            throw GLMError.badResponse
        }
        return result
    }

    func repairTranscript(sentences: [String], glossary: [String: String]) async throws -> [TermEdit] {
        let glossaryBlock = glossary.isEmpty ? "None" : glossary.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        let system = """
        You are a transcript proofreader. You may ONLY replace mis-heard words with exact entries from the provided glossary. Never rewrite anything else. Respond with strict JSON only: {"edits":[{"original":"","replacement":"","reason":"glossary"}]}. An empty edits array means no changes.
        """
        let user = """
        Transcript:
        \(sentences.joined(separator: "\n"))

        Glossary (allowed replacements):
        \(glossaryBlock)
        """
        let content = try await complete(
            messages: [Self.textMessage(role: "system", content: system), Self.textMessage(role: "user", content: user)],
            maxTokens: 4096
        )
        guard let data = content.data(using: .utf8),
              let edits = try? JSONDecoder().decode(TermEditList.self, from: data).edits else {
            throw GLMError.badResponse
        }
        return edits
    }

    func noteFromSlide(imageDataURL: String, language: String) async throws -> StudyResult {
        let system = """
        You are a study-notes engine reading a photo of a lecture slide. Respond with strict JSON only, no markdown. Schema: {"note":{"title":"","headings":[{"heading":"","bullets":[""],"source_sentence_ids":[]}],"key_terms":[{"term":"","definition":""}],"summary":""},"flashcards":[{"question":"","answer":"","tag":""}],"quiz":[{"question":"","options":["a","b","c","d"],"answer_index":0,"explanation":""}]}. Rules: summary at most 5 sentences; at most 20 flashcards; at most 5 quiz items with exactly 4 options each; write everything in \(language).
        """
        let content = try await complete(
            messages: [Self.textMessage(role: "system", content: system), Self.visionMessage(text: "Extract structured study notes from this slide photo.", imageDataURL: imageDataURL)],
            maxTokens: 8192
        )
        guard let data = content.data(using: .utf8),
              let result = try? JSONDecoder().decode(StudyResult.self, from: data) else {
            throw GLMError.badResponse
        }
        return result
    }

    func repairCandidates(sentence: String) async throws -> [String] {
        let system = """
        You are a transcription assistant. A sentence may contain mis-heard words. Propose exactly 3 plausible corrected variants, preserving meaning. Respond with strict JSON only: {"candidates":["","",""]}.
        """
        let content = try await complete(
            messages: [Self.textMessage(role: "system", content: system), Self.textMessage(role: "user", content: sentence)],
            maxTokens: 1024
        )
        guard let data = content.data(using: .utf8),
              let list = try? JSONDecoder().decode(RepairCandidateList.self, from: data).candidates else {
            throw GLMError.badResponse
        }
        return list
    }
}
