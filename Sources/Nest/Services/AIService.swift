import Foundation

struct AIClassificationResult: Codable {
    var documentType: String?
    var category: String
    var subcategory: String?
    var summary: String?
    var tags: [String]
    var vendor: String?
    var person: String?
    var organization: String?
    var documentDate: String?
    var amount: Double?
    var currency: String?
    var confidence: Double
    var suggestedFilename: String?
    var reason: String?
}

struct AISearchFilters: Codable {
    var documentType: String?
    var category: String?
    var keywords: [String]?
    var vendor: String?
    var dateFrom: String?
    var dateTo: String?
    var amountMin: Double?
    var amountMax: Double?
    var currency: String?
}

struct AIDocumentDateEvent: Codable {
    var type: String // one of ExpiryEventType's raw values, lowercased (e.g. "expiry", "valid_from")
    var date: String // yyyy-MM-dd
    var confidence: Double
    var explicit: Bool
    var sourceText: String?

    enum CodingKeys: String, CodingKey {
        case type, date, confidence, explicit
        case sourceText = "source_text"
    }
}

struct AIDocumentEventsResult: Codable {
    var documentType: String?
    var importantDates: [AIDocumentDateEvent]

    enum CodingKeys: String, CodingKey {
        case documentType = "document_type"
        case importantDates = "important_dates"
    }
}

enum AIServiceError: Error, LocalizedError {
    case notConfigured
    case invalidResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI is not enabled or no API key is configured."
        case .invalidResponse: return "The AI response could not be parsed."
        case .network(let message): return "Network error: \(message)"
        }
    }
}

/// Abstraction so the AI provider can be swapped without touching call sites.
protocol AIService {
    func classifyFile(filename: String, extractedText: String?) async throws -> AIClassificationResult
    func summarizeFile(filename: String, extractedText: String) async throws -> String
    func suggestFilename(filename: String, classification: AIClassificationResult) async throws -> String
    func interpretSearchQuery(_ query: String) async throws -> AISearchFilters
    func answer(question: String, context: String) async throws -> String
    func extractDocumentEvents(filename: String, extractedText: String) async throws -> AIDocumentEventsResult
}
