import Foundation

/// Local, free, unlimited-use AI via Ollama (https://ollama.com) running on
/// the user's own Mac. No API key, no rate limits, no per-call cost, no data
/// ever leaves the machine — requests go to localhost only.
struct OllamaAIService: AIService {
    private let host: String
    private let model: String
    private let chatEndpoint: URL

    init(host: String, model: String) {
        self.host = host
        self.model = model
        self.chatEndpoint = URL(string: host.trimmingCharacters(in: .init(charactersIn: "/")) + "/api/chat")!
    }

    /// GET /api/tags — used by Settings to confirm Ollama is running and to
    /// list installed models before the user picks one. Returns nil if
    /// Ollama isn't reachable at all, or an (possibly empty) array of
    /// installed model names if it is.
    static func listModels(host: String) async -> [String]? {
        guard let url = URL(string: host.trimmingCharacters(in: .init(charactersIn: "/")) + "/api/tags") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return nil }
        return models.compactMap { $0["name"] as? String }
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

    func extractDocumentEvents(filename: String, extractedText: String) async throws -> AIDocumentEventsResult {
        let content = String(extractedText.prefix(6000))
        let raw = try await send(system: Self.documentEventsSystemPrompt, user: "Filename: \(filename)\n\nExtracted content:\n\(content)")
        if let parsed = Self.parseDocumentEvents(raw) {
            return parsed
        }
        let correction = "Your previous response was not valid JSON matching the schema. Reply with ONLY the JSON object.\nPrevious response:\n\(raw)"
        let retry = try await send(system: Self.documentEventsSystemPrompt, user: "Filename: \(filename)\n\nExtracted content:\n\(content)\n\n\(correction)")
        guard let retryParsed = Self.parseDocumentEvents(retry) else {
            throw AIServiceError.invalidResponse
        }
        return retryParsed
    }

    // MARK: - Networking

    private func send(system: String, user: String) async throws -> String {
        var request = URLRequest(url: chatEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.network("Couldn't reach Ollama at \(host). Is it running? (\(error.localizedDescription))")
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.network("HTTP \(status): \(bodyText.prefix(200))")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let text = message["content"] as? String else {
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

    private static func parseDocumentEvents(_ raw: String) -> AIDocumentEventsResult? {
        guard let json = extractJSON(raw), let data = json.data(using: .utf8) else { return nil }
        guard let result = try? JSONDecoder().decode(AIDocumentEventsResult.self, from: data) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let validTypes = Set(ExpiryEventType.allCases.map { $0.rawValue.lowercased() })
        let valid = result.importantDates.allSatisfy { event in
            validTypes.contains(event.type.lowercased()) && formatter.date(from: event.date) != nil
        }
        return valid ? result : nil
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

    private static let documentEventsSystemPrompt = """
    You find date-related events in a document and classify what each date MEANS. Reply with ONLY a strict JSON object matching this exact schema, no prose, no markdown fences:
    {
      "document_type": "",
      "important_dates": [
        {
          "type": "",
          "date": "",
          "confidence": 0.0,
          "explicit": true,
          "source_text": ""
        }
      ]
    }
    "type" MUST be exactly one of (lowercase): \(ExpiryEventType.allCases.map { $0.rawValue.lowercased() }.joined(separator: ", ")).
    Rules:
    - A flight/hotel/appointment date is "event_date", NOT "expiry". Only use "expiry" when the document explicitly states something expires, becomes invalid, or is no longer valid on that date.
    - A payment/submission deadline is "due_date" or "deadline", never "expiry".
    - "date" MUST be in YYYY-MM-DD format.
    - "explicit" is true only if the document states this exact date; false if you calculated it from a stated duration (e.g. "valid for 12 months from issue").
    - "source_text" is the exact (or near-exact) snippet of the document that this date came from — this is shown to the user to justify the detection, so do not paraphrase it away.
    - "confidence" is your genuine 0.0-1.0 confidence that this date and its meaning are correct. Use a LOW confidence (below 0.6) if the meaning is ambiguous — do not guess "expiry" just because a date is present.
    - If the document has no meaningful dates, return an empty "important_dates" array.
    - Never invent a date that is not present in the text.
    """
}
