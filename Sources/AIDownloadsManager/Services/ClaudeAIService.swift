import Foundation

/// Claude-backed implementation of AIService. Sends only the extracted text
/// needed for a given call — never whole files, never the full library.
struct ClaudeAIService: AIService {
    private let apiKey: String
    private let model: String
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String, model: String = "claude-sonnet-5") {
        self.apiKey = apiKey
        self.model = model
    }

    // MARK: - Public API

    func classifyFile(filename: String, extractedText: String?) async throws -> AIClassificationResult {
        let content = String((extractedText ?? "").prefix(6000))
        let system = Self.classificationSystemPrompt
        let user = """
        Filename: \(filename)

        Extracted content (may be empty for non-text files):
        \(content.isEmpty ? "(no extractable text)" : content)
        """
        let raw = try await send(system: system, user: user)
        if let parsed = Self.parseClassification(raw) {
            return parsed
        }
        // One correction retry, per spec.
        let correction = """
        Your previous response was not valid JSON matching the schema. Reply with ONLY the JSON object, no prose, no markdown fences.
        Previous response:
        \(raw)
        """
        let retryRaw = try await send(system: system, user: user + "\n\n" + correction)
        guard let retryParsed = Self.parseClassification(retryRaw) else {
            throw AIServiceError.invalidResponse
        }
        return retryParsed
    }

    func summarizeFile(filename: String, extractedText: String) async throws -> String {
        let content = String(extractedText.prefix(8000))
        let system = "You summarize documents in 1-2 concise sentences. Reply with plain text only, no preamble."
        let user = "Filename: \(filename)\n\nContent:\n\(content)"
        return try await send(system: system, user: user).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func suggestFilename(filename: String, classification: AIClassificationResult) async throws -> String {
        if let suggested = classification.suggestedFilename, !suggested.isEmpty {
            return FilenameSanitizer.sanitize(suggested)
        }
        let system = "You suggest a clear, descriptive macOS-safe filename (no slashes/colons) including extension. Reply with ONLY the filename."
        let user = """
        Original filename: \(filename)
        Document type: \(classification.documentType ?? "unknown")
        Vendor: \(classification.vendor ?? "unknown")
        Date: \(classification.documentDate ?? "unknown")
        Amount: \(classification.amount.map { String($0) } ?? "unknown") \(classification.currency ?? "")
        """
        let raw = try await send(system: system, user: user)
        return FilenameSanitizer.sanitize(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func interpretSearchQuery(_ query: String) async throws -> AISearchFilters {
        let system = """
        Translate the user's natural-language search into a JSON object with these optional fields only:
        documentType (string), category (must be one of: \(CategoryTaxonomy.allCategories.joined(separator: ", "))),
        keywords (array of strings), vendor (string), dateFrom (YYYY-MM-DD), dateTo (YYYY-MM-DD),
        amountMin (number), amountMax (number), currency (3-letter code).
        Omit fields you cannot infer. Reply with ONLY the JSON object.
        Today's date is \(Self.todayString()).
        """
        let raw = try await send(system: system, user: query)
        guard let json = Self.extractJSON(raw), let data = json.data(using: .utf8),
              let filters = try? JSONDecoder().decode(AISearchFilters.self, from: data) else {
            throw AIServiceError.invalidResponse
        }
        return filters
    }

    func answer(question: String, context: String) async throws -> String {
        let system = "Answer the user's question about this specific document using only the provided context. If the answer isn't in the context, say so briefly."
        let user = "Context:\n\(String(context.prefix(8000)))\n\nQuestion: \(question)"
        return try await send(system: system, user: user).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Networking

    private func send(system: String, user: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.network("HTTP \(status): \(bodyText.prefix(200))")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let text = contentArray.first?["text"] as? String else {
            throw AIServiceError.invalidResponse
        }
        return text
    }

    // MARK: - Parsing helpers

    private static func extractJSON(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
            text = text.replacingOccurrences(of: "```", with: "")
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        return String(text[start...end])
    }

    private static func parseClassification(_ raw: String) -> AIClassificationResult? {
        guard let json = extractJSON(raw), let data = json.data(using: .utf8) else { return nil }
        guard let result = try? JSONDecoder().decode(AIClassificationResult.self, from: data) else { return nil }
        guard CategoryTaxonomy.isValid(category: result.category, subcategory: result.subcategory) else { return nil }
        return result
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static let classificationSystemPrompt = """
    You classify a downloaded file for a personal file-organization app. Reply with ONLY a strict JSON object matching this exact schema, no prose, no markdown fences:
    {
      "documentType": "",
      "category": "",
      "subcategory": "",
      "summary": "",
      "tags": [],
      "vendor": null,
      "person": null,
      "organization": null,
      "documentDate": null,
      "amount": null,
      "currency": null,
      "confidence": 0.0,
      "suggestedFilename": "",
      "reason": ""
    }
    "category" MUST be exactly one of: \(CategoryTaxonomy.allCategories.joined(separator: ", ")).
    "subcategory" must be one of the valid subcategories for that category.
    "confidence" is 0.0-1.0, your genuine confidence in this classification.
    "reason" is a one-sentence, human-readable explanation of why you chose this category.
    """
}
