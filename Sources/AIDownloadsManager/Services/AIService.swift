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
}
