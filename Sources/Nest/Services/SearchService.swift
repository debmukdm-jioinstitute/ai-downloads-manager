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

    static func search(query: String, in files: [FileRecord], aiFilters: AISearchFilters?) async -> [FileRecord] {
        await searchScored(query: query, in: files, aiFilters: aiFilters).map(\.file)
    }

    /// Same ranking as `search`, but keeps each match's raw relevance score
    /// so callers can show a confidence figure (e.g. normalized against the
    /// top score in the result set) instead of just an ordered list.
    ///
    /// `onProgress` (files scanned so far, total) is reported every
    /// `progressChunkSize` files with a `Task.yield()` in between, so a
    /// caller-driven progress bar actually redraws mid-scan instead of
    /// jumping straight to 100% — real progress over the same fast byte
    /// scan, not simulated busywork.
    private static let progressChunkSize = 15

    static func searchScored(
        query: String,
        in files: [FileRecord],
        aiFilters: AISearchFilters?,
        onProgress: (@MainActor (Int, Int) -> Void)? = nil
    ) async -> [(file: FileRecord, score: Int)] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return files.map { ($0, 0) } }
        let lowerQuery = trimmed.lowercased()
        let queryWords = lowerQuery.split(separator: " ").map(String.init).filter { $0.count > 2 }
        let queryPhraseBytes = asciiLowerBytes(lowerQuery)
        let wordBytes = queryWords.map { asciiLowerBytes($0) }

        var scored: [(FileRecord, Int)] = []
        let total = files.count

        for (index, file) in files.enumerated() {
            if let score = score(file, lowerQuery: lowerQuery, queryWords: queryWords, queryPhraseBytes: queryPhraseBytes, wordBytes: wordBytes, aiFilters: aiFilters), score > 0 {
                scored.append((file, score))
            }
            let scannedSoFar = index + 1
            if scannedSoFar % progressChunkSize == 0 || scannedSoFar == total {
                onProgress?(scannedSoFar, total)
                await Task.yield()
            }
        }

        return scored.sorted { $0.1 > $1.1 }
    }

    /// One file's relevance score, or nil if an objective structured filter
    /// (date/amount/currency) rules it out outright. Pulled out of the scan
    /// loop above so progress reporting isn't tangled up with early-exit
    /// filter logic.
    private static func score(
        _ file: FileRecord,
        lowerQuery: String,
        queryWords: [String],
        queryPhraseBytes: [UInt8],
        wordBytes: [[UInt8]],
        aiFilters: AISearchFilters?
    ) -> Int? {
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

        // Stage 5: AI-derived structured filters.
        //
        // category/vendor/documentType/keywords are the AI's own
        // classification *guess* for whatever free text it couldn't
        // otherwise place — proven unreliable on a real query ("ENEL"),
        // where the local model forced a category guess (the prompt
        // requires one of a fixed enum) that didn't match the file's
        // real category, and the resulting hard `continue` filtered out
        // every file in the library, including one with the word right
        // in its filename. They now only ever add confidence on a match
        // and never veto a file that already has real local evidence.
        //
        // date/amount/currency stay hard constraints: they only appear
        // in aiFilters when the query itself contained something
        // date-or-number-shaped, which a small model has no real
        // temptation to hallucinate for a query that doesn't.
        //
        // But this same small model also doesn't reliably follow "omit
        // fields you cannot infer" — measured on this exact query, it
        // filled the *entire* schema anyway: amountMin/amountMax as 0,
        // currency/vendor/dates as "". Those decode as present-but-empty,
        // not nil, so every string field is treated as unset when empty
        // and both amount bounds are ignored at 0 (a real lower bound of
        // exactly $0 has nothing to constrain; a real upper bound of $0
        // would exclude everything, which is never what "search" means).
        if let filters = aiFilters {
            if let cat = filters.category, !cat.isEmpty, cat.caseInsensitiveCompare(file.category) == .orderedSame { score += 20 }
            if let vendor = filters.vendor, !vendor.isEmpty, file.detectedVendor?.localizedCaseInsensitiveContains(vendor) == true { score += 20 }
            if let docType = filters.documentType, !docType.isEmpty, file.detectedDocumentType?.localizedCaseInsensitiveContains(docType) == true { score += 15 }
            for keyword in filters.keywords ?? [] where !keyword.isEmpty && (relates(keyword, to: lowerQuery, words: queryWords) || lowerFilename.contains(keyword.lowercased())) { score += 5 }

            if let currency = filters.currency, !currency.isEmpty, file.detectedCurrency?.caseInsensitiveCompare(currency) != .orderedSame { return nil }
            if let minAmt = filters.amountMin, minAmt > 0, (file.detectedAmount ?? -1) < minAmt { return nil }
            if let maxAmt = filters.amountMax, maxAmt > 0, (file.detectedAmount ?? .greatestFiniteMagnitude) > maxAmt { return nil }
            if let dateFrom = parseDate(filters.dateFrom), let fileDate = file.detectedDate ?? file.dateDownloaded as Date?, fileDate < dateFrom { return nil }
            if let dateTo = parseDate(filters.dateTo), let fileDate = file.detectedDate ?? file.dateDownloaded as Date?, fileDate > dateTo { return nil }
        }

        return score
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
