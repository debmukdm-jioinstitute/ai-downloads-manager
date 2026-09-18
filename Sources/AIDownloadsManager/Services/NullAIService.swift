import Foundation

/// Used whenever AI is disabled or unconfigured, so the rest of the app never
/// has to branch on "is AI on?" — it just gets a service that always fails
/// cleanly and callers fall back to local classification.
struct NullAIService: AIService {
    func classifyFile(filename: String, extractedText: String?) async throws -> AIClassificationResult {
        throw AIServiceError.notConfigured
    }
    func summarizeFile(filename: String, extractedText: String) async throws -> String {
        throw AIServiceError.notConfigured
    }
    func suggestFilename(filename: String, classification: AIClassificationResult) async throws -> String {
        throw AIServiceError.notConfigured
    }
    func interpretSearchQuery(_ query: String) async throws -> AISearchFilters {
        throw AIServiceError.notConfigured
    }
    func answer(question: String, context: String) async throws -> String {
        throw AIServiceError.notConfigured
    }
}
