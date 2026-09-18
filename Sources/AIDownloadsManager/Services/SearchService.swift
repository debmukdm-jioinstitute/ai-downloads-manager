import Foundation

/// Staged natural-language search over the already-indexed local library.
/// Only the query text itself is ever sent to Claude — never the file library.
@MainActor
enum SearchService {

    static func search(query: String, in files: [FileRecord], aiFilters: AISearchFilters?) -> [FileRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return files }
        let lowerQuery = trimmed.lowercased()

        var scored: [(FileRecord, Int)] = []

        for file in files {
            var score = 0

            // Stage 1: exact / partial filename match.
            if file.filename.lowercased() == lowerQuery { score += 100 }
            else if file.filename.lowercased().contains(lowerQuery) { score += 40 }

            // Stage 2: metadata (category, subcategory, vendor, document type).
            if let sub = file.subcategory, lowerQuery.contains(sub.lowercased()) { score += 25 }
            if lowerQuery.contains(file.category.lowercased()) { score += 20 }
            if let vendor = file.detectedVendor, lowerQuery.contains(vendor.lowercased()) { score += 30 }
            if let docType = file.detectedDocumentType, lowerQuery.contains(docType.lowercased()) { score += 25 }

            // Stage 3: extracted / OCR text.
            if let text = file.extractedText, text.lowercased().contains(lowerQuery) { score += 15 }
            if let ocr = file.ocrText, ocr.lowercased().contains(lowerQuery) { score += 15 }
            for word in lowerQuery.split(separator: " ") where word.count > 2 {
                if file.extractedText?.lowercased().contains(word) == true { score += 3 }
                if file.aiSummary?.lowercased().contains(word) == true { score += 4 }
            }

            // Stage 4: tags.
            for tag in file.tags where lowerQuery.contains(tag.lowercased()) { score += 10 }

            // Stage 5: AI-derived structured filters, applied as hard constraints when present.
            if let filters = aiFilters {
                if let cat = filters.category, cat.caseInsensitiveCompare(file.category) != .orderedSame { continue }
                if let vendor = filters.vendor, file.detectedVendor?.localizedCaseInsensitiveContains(vendor) != true { continue }
                if let docType = filters.documentType, file.detectedDocumentType?.localizedCaseInsensitiveContains(docType) != true { continue }
                if let currency = filters.currency, file.detectedCurrency != currency { continue }
                if let minAmt = filters.amountMin, (file.detectedAmount ?? -1) < minAmt { continue }
                if let maxAmt = filters.amountMax, (file.detectedAmount ?? .greatestFiniteMagnitude) > maxAmt { continue }
                if let dateFrom = parseDate(filters.dateFrom), let fileDate = file.detectedDate ?? file.dateDownloaded as Date?, fileDate < dateFrom { continue }
                if let dateTo = parseDate(filters.dateTo), let fileDate = file.detectedDate ?? file.dateDownloaded as Date?, fileDate > dateTo { continue }
                score += 50
            }

            if score > 0 { scored.append((file, score)) }
        }

        return scored.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
