import Foundation
import StoreKit

final class GLMService: ObservableObject {
    static let shared = GLMService()

    static let appId = "cramjam" // Worker D1 whitelist (appId ↔ bundleId binding, verified by Worker)
    static let workerURL = URL(string: "https://cramjam-api.calcs.top")!
    static let workerFallbackURL = URL(string: "https://cramjam-proxy.iocompile67692.workers.dev")!
    static let model = "glm-5.3-flash" // Worker proxy channel model (fixed server-side)

    enum GLMError: LocalizedError {
        case insufficientCredits
        case rateLimited
        case unauthorized
        case notConfigured
        case consentDeclined
        case server(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .insufficientCredits:
                return "Cloud credits are used up. Notes were generated on-device instead."
            case .rateLimited:
                return "Too many cloud requests right now. Please try again later — notes were generated on-device instead."
            case .unauthorized:
                return "This is a Pro feature. Restore your purchase or subscribe to continue — notes were generated on-device instead."
            case .notConfigured:
                return "Cloud AI needs a subscription or your own API key in Settings — notes were generated on-device instead."
            case .consentDeclined:
                return "Cloud generation is off — notes were generated on-device instead. You can enable it in Settings → AI Data & Privacy."
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

    // MARK: - Credentials

    /// devKey only exists in local debug builds (GLMProxySecret.txt is excluded from
    /// Release via EXCLUDED_SOURCE_FILE_NAMES), so production always uses the JWS channel.
    private var proxyDevKey: String? {
        guard let url = Bundle.main.url(forResource: "GLMProxySecret", withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    /// Signed JWS of the current auto-renewable subscription.
    /// Note: jwsRepresentation lives on the VerificationResult, NOT on the Transaction;
    /// jsonRepresentation is unsigned and would be rejected by the Worker with 401.
    private func currentEntitlementJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  transaction.productType == .autoRenewable else { continue }
            let jws = result.jwsRepresentation
            if !jws.isEmpty {
                return jws
            }
        }
        return nil
    }

    // MARK: - Public API

    func complete(messages: [[String: Any]], maxTokens: Int) async throws -> String {
        // Guideline 5.1.2(i) gate: no personal content leaves the device without explicit consent
        guard await CloudConsentCenter.shared.waitForConsent() else {
            throw GLMError.consentDeclined
        }
        let byoKey = KeychainHelper.glmKey
        if !byoKey.isEmpty {
            // BYO channel: standard OpenAI-compatible payload — no GLM-only fields
            let payload: [String: Any] = [
                "model": BYOConfig.modelID,
                "messages": messages,
                "max_tokens": maxTokens,
                "response_format": ["type": "json_object"],
                "temperature": 0.3
            ]
            let content = try await sendDirect(payload, key: byoKey)
            lastRouteWasOnDevice = false
            return content
        }
        // Worker channel: GLM requires thinking + response_format
        let payload: [String: Any] = [
            "model": Self.model,
            "messages": messages,
            "thinking": ["level": "low"], // required: model forces thinking, disabling returns 1210
            "max_tokens": maxTokens, // must be generous: text ≥4096, vision/structured ≥8192 (reasoning counts toward budget)
            "response_format": ["type": "json_object"],
            "temperature": 0.3
        ]
        let content = try await sendWorker(payload)
        lastRouteWasOnDevice = false
        return content
    }

    // MARK: - Worker channel (subscription JWS → devKey)

    private func sendWorker(_ payload: [String: Any]) async throws -> String {
        var body: [String: Any] = [
            "appId": Self.appId,
            "userId": KeychainHelper.userUUID,
            "payload": payload
        ]
        if let jws = await currentEntitlementJWS() {
            body["appTransaction"] = jws
        } else if let devKey = proxyDevKey {
            body["devKey"] = devKey
        } else {
            throw GLMError.notConfigured
        }
        do {
            return try await postWorker(Self.workerURL, body: body)
        } catch let error as GLMError {
            // Fallback line: only for transient transport/empty issues, not auth errors
            switch error {
            case .badResponse, .server:
                return try await postWorker(Self.workerFallbackURL, body: body)
            default:
                throw error
            }
        } catch {
            // Network failure on primary → try fallback once
            return try await postWorker(Self.workerFallbackURL, body: body)
        }
    }

    private func postWorker(_ url: URL, body: [String: Any]) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
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

    // MARK: - BYO key channel

    private func sendDirect(_ payload: [String: Any], key: String) async throws -> String {
        guard let endpoint = URL(string: BYOConfig.baseURL) else { throw GLMError.badResponse }
        var request = URLRequest(url: endpoint, timeoutInterval: 90)
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

// MARK: - BYO provider configuration (multi-model, per ios-openai-module standard)

struct BYOPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let baseURL: String
    let modelID: String
    let isCustom: Bool
}

enum BYOConfig {
    static let defaultBaseURL = "https://api.z.ai/api/paas/v4/chat/completions"
    static let defaultModelID = "glm-5.3-flash"

    // Presets follow the ios-openai-module provider table exactly (URL format is the #1 cause of 404s)
    static let presets: [BYOPreset] = [
        BYOPreset(id: "glm", name: "GLM", baseURL: "https://api.z.ai/api/paas/v4/chat/completions", modelID: "glm-5.3-flash", isCustom: false),
        BYOPreset(id: "gpt", name: "GPT", baseURL: "https://api.openai.com/v1/chat/completions", modelID: "gpt-4o-mini", isCustom: false),
        BYOPreset(id: "gemini", name: "Gemini", baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", modelID: "gemini-2.5-flash", isCustom: false),
        BYOPreset(id: "deepseek", name: "DeepSeek", baseURL: "https://api.deepseek.com/chat/completions", modelID: "deepseek-chat", isCustom: false),
        BYOPreset(id: "claude", name: "Claude", baseURL: "https://api.anthropic.com/v1/chat/completions", modelID: "claude-sonnet-4-5", isCustom: false),
        BYOPreset(id: "custom", name: "Custom", baseURL: "", modelID: "", isCustom: true)
    ]

    static func preset(id: String) -> BYOPreset? {
        presets.first { $0.id == id }
    }

    private static var storedPresetID: String? {
        UserDefaults.standard.string(forKey: "byoPresetID")
    }

    static var baseURL: String {
        if let id = storedPresetID, let preset = preset(id: id) {
            return UserDefaults.standard.string(forKey: "byoBaseURL").flatMap { $0.isEmpty ? nil : $0 } ?? preset.baseURL
        }
        return UserDefaults.standard.string(forKey: "byoBaseURL").flatMap { $0.isEmpty ? nil : $0 } ?? defaultBaseURL
    }

    static var modelID: String {
        if let id = storedPresetID, let preset = preset(id: id) {
            return UserDefaults.standard.string(forKey: "byoModelID").flatMap { $0.isEmpty ? nil : $0 } ?? preset.modelID
        }
        return UserDefaults.standard.string(forKey: "byoModelID").flatMap { $0.isEmpty ? nil : $0 } ?? defaultModelID
    }

    static var isConfigured: Bool {
        !baseURL.isEmpty && !modelID.isEmpty && URL(string: baseURL) != nil
    }

    static func save(presetID: String, baseURL: String, modelID: String) {
        UserDefaults.standard.set(presetID, forKey: "byoPresetID")
        UserDefaults.standard.set(baseURL, forKey: "byoBaseURL")
        UserDefaults.standard.set(modelID, forKey: "byoModelID")
    }

    static var providerDisplayName: String {
        switch storedPresetID {
        case "glm": return "GLM"
        case "gpt": return "GPT"
        case "gemini": return "Gemini"
        case "deepseek": return "DeepSeek"
        case "claude": return "Claude"
        default: return "Custom"
        }
    }
}

extension GLMService {
    /// Minimal-cost connectivity test for the BYO channel (max_tokens: 10, per module standard)
    func testBYOConnection(key: String) async throws -> String {
        guard BYOConfig.isConfigured else { throw GLMError.badResponse }
        let payload: [String: Any] = [
            "model": BYOConfig.modelID,
            "messages": [["role": "user", "content": "Reply with exactly: OK"]],
            "max_tokens": 10
        ]
        return try await sendDirect(payload, key: key)
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
