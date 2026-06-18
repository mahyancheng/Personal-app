import Foundation

/// Talks to any OpenAI-compatible `/v1/chat/completions` endpoint.
/// Point `baseURL` at your sub2api gateway (which routes to your ChatGPT
/// subscription). Swapping to the real OpenAI/Anthropic API later is just a
/// Base URL + key change in Settings — no code edits.
struct LLMClient {

    struct Config {
        var baseURL: String
        var apiKey: String
        var model: String

        static var current: Config {
            let d = UserDefaults.standard
            return Config(
                baseURL: (d.string(forKey: "baseURL") ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey:  (d.string(forKey: "apiKey") ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                model:   (d.string(forKey: "model") ?? "gpt-4o").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    enum LLMError: LocalizedError {
        case notConfigured
        case badURL
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Open Settings (gear icon) and set your sub2api Base URL and API key first."
            case .badURL:        return "That Base URL doesn't look valid."
            case .badResponse(let s): return s
            }
        }
    }

    /// Asks the model to emit a full HTML document for the requested screen.
    func generateHTML(prompt: String, context: String) async throws -> String {
        let cfg = Config.current
        guard !cfg.baseURL.isEmpty, !cfg.apiKey.isEmpty else { throw LLMError.notConfigured }

        var base = cfg.baseURL
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/v1/chat/completions") else { throw LLMError.badURL }

        let body: [String: Any] = [
            "model": cfg.model.isEmpty ? "gpt-4o" : cfg.model,
            "temperature": 0.4,
            "messages": [
                ["role": "system", "content": SystemPrompt.text],
                ["role": "user", "content": "App context:\n\(context)\n\nUser request:\n\(prompt)"]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(cfg.apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw LLMError.badResponse("No HTTP response from the endpoint.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let txt = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.badResponse("HTTP \(http.statusCode). \(txt.prefix(400))")
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw LLMError.badResponse("Unexpected response shape from the endpoint.")
        }
        return Self.stripFences(content)
    }

    /// Models sometimes wrap output in ```html ... ``` despite instructions.
    static func stripFences(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if t.hasSuffix("```") {
                t = String(t.dropLast(3))
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
