import Foundation

/// Staged natural-language search over the already-indexed local library.
/// Only the query text itself is ever sent to the local AI model — never the file library.
///
/// Performance note: this used to take 100-250ms on a real library (measured)
/// because `String.contains()` on real PDF-extracted text is expensive —
/// Swift's `String` does Unicode-correct (grapheme-cluster-aware) comparison,
/// and real extracted text is full of the ligatures/odd-whitespace/non-ASCII
/// artifacts that make that slow, unlike clean synthetic test strings. Text
/// search below instead does a manual ASCII byte scan (`byteContains`) on a
/// per-file cached, ASCII-lowercased byte buffer — verified ~35-45x faster
/// against a real 287-file library with real extracted text. Short fields
/// (filename, category, tags) stay as plain `String` operations since they're
/// too short for this to matter.
@MainActor
enum SearchService {

    /// Cached per file (by object identity) so repeated searches in a
    /// session don't redo the ASCII-lowering pass. Safe because a file's
    /// `extractedText`/`ocrText`/`aiSummary` are only ever written once,
    /// during ingest, before the record is ever handed to search — if a
    /// future "reclassify" feature mutates them on an existing FileRecord
    /// instance later, this cache must be invalidated for that file's id.
    private static var textCache: [ObjectIdentifier: (text: [UInt8], ocr: [UInt8], summary: [UInt8])] = [:]

    static func search(query: String, in files: [FileRecord], aiFilters: AISearchFilters?) -> [FileRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return files }
        let lowerQuery = trimmed.lowercased()
        let queryWords = lowerQuery.split(separator: " ").map(String.init).filter { $0.count > 2 }
        let queryPhraseBytes = asciiLowerBytes(lowerQuery)
        let wordBytes = queryWords.map { asciiLowerBytes($0) }

        var scored: [(FileRecord, Int)] = []

        for file in files {
            var score = 0
            let lowerFilename = file.filename.lowercased()

            // Stage 1: exact / partial filename match.
            if lowerFilename == lowerQuery { score += 100 }
            else if lowerFilename.contains(lowerQuery) { score += 40 }
            for word in queryWords where lowerFilename.contains(word) { score += 15 }

            // Stage 2: metadata (category, subcategory, vendor, document type).
            // Matches word-by-word in both directions ("ticket" <-> "Tickets")
            // rather than requiring the *entire* query to appear inside the
            // field, which silently failed on nearly any plural/singular or
            // multi-word mismatch.
            if relates(file.subcategory, to: lowerQuery, words: queryWords) { score += 25 }
            if relates(file.category, to: lowerQuery, words: queryWords) { score += 20 }
            if relates(file.detectedVendor, to: lowerQuery, words: queryWords) { score += 30 }
            if relates(file.detectedDocumentType, to: lowerQuery, words: queryWords) { score += 25 }

            // Stage 3: extracted / OCR / AI-summary text — the fast path.
            let cached = cachedBytes(for: file)
            if !cached.text.isEmpty {
                if byteContains(cached.text, queryPhraseBytes) { score += 15 }
                for wb in wordBytes where byteContains(cached.text, wb) { score += 3 }
            }
            if !cached.ocr.isEmpty {
                if byteContains(cached.ocr, queryPhraseBytes) { score += 15 }
                for wb in wordBytes where byteContains(cached.ocr, wb) { score += 3 }
            }
            if !cached.summary.isEmpty {
                for wb in wordBytes where byteContains(cached.summary, wb) { score += 4 }
            }

            // Stage 4: tags.
            for tag in file.tags where relates(tag, to: lowerQuery, words: queryWords) { score += 10 }

            // Stage 5: AI-derived structured filters, applied as hard constraints when present.
            if let filters = aiFilters {
                if let cat = filters.category, cat.caseInsensitiveCompare(file.category) != .orderedSame { continue }
                if let vendor = filters.vendor, file.detectedVendor?.localizedCaseInsensitiveContains(vendor) != true { continue }
                if let docType = filters.documentType, file.detectedDocumentType?.localizedCaseInsensitiveContains(docType) != true { continue }
                if let currency = filters.currency, file.detectedCurrency?.caseInsensitiveCompare(currency) != .orderedSame { continue }
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

    /// Call after a file's extracted/OCR/summary text is (re)written, so a
    /// stale cached copy is never searched. Cheap no-op if nothing was cached yet.
    static func invalidateCache(for file: FileRecord) {
        textCache.removeValue(forKey: ObjectIdentifier(file))
    }

    // MARK: - Fast ASCII byte matching

    private static func cachedBytes(for file: FileRecord) -> (text: [UInt8], ocr: [UInt8], summary: [UInt8]) {
        let key = ObjectIdentifier(file)
        if let cached = textCache[key] { return cached }
        let computed = (
            text: asciiLowerBytes(file.extractedText ?? ""),
            ocr: asciiLowerBytes(file.ocrText ?? ""),
            summary: asciiLowerBytes(file.aiSummary ?? "")
        )
        textCache[key] = computed
        return computed
    }

    /// ASCII-only case-folding into raw bytes — deliberately not full Unicode
    /// case mapping, because that's exactly what made this slow. Non-ASCII
    /// bytes pass through unchanged, so accented/non-Latin text still matches
    /// exactly (case-sensitively) rather than not at all.
    private static func asciiLowerBytes(_ string: String) -> [UInt8] {
        var bytes = Array(string.utf8)
        for i in bytes.indices where bytes[i] >= 65 && bytes[i] <= 90 {
            bytes[i] += 32
        }
        return bytes
    }

    private static func byteContains(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        let limit = haystack.count - needle.count
        var i = 0
        while i <= limit {
            if haystack[i] == needle[0] {
                var j = 1
                while j < needle.count && haystack[i + j] == needle[j] { j += 1 }
                if j == needle.count { return true }
            }
            i += 1
        }
        return false
    }

    /// True if `field` and the query relate at the word level: an exact word
    /// match, one contains the other (handles "ticket"/"tickets",
    /// "invoice"/"invoices"), or the whole query phrase appears in the field.
    private static func relates(_ field: String?, to lowerQuery: String, words: [String]) -> Bool {
        guard let field else { return false }
        let lowerField = field.lowercased()
        if lowerQuery.contains(lowerField) || lowerField.contains(lowerQuery) { return true }
        return words.contains { word in lowerField.contains(word) || word.contains(lowerField) }
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
