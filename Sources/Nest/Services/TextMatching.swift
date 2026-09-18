import Foundation

/// Whole-word substring matching for classification keywords.
///
/// Plain `String.contains` is what caused a real bug: the invoice keyword
/// "bill" matched inside "billion", "billing", "bill of lading", turning any
/// document that mentions a dollar amount in the billions into a
/// misclassified "invoice" — verified against 13 real files (research
/// reports, an insurance certificate, an offer letter, a book) that all got
/// tagged Finance/Invoices at exactly the same confidence for exactly this
/// reason. Every keyword lookup against extracted document text should go
/// through here instead of `.contains`.
enum TextMatching {
    static func containsWord(_ haystack: String, _ phrase: String) -> Bool {
        guard !phrase.isEmpty else { return false }
        var searchStart = haystack.startIndex
        while let range = haystack.range(of: phrase, range: searchStart..<haystack.endIndex) {
            let beforeOK = range.lowerBound == haystack.startIndex || !haystack[haystack.index(before: range.lowerBound)].isLetter
            let afterOK = range.upperBound == haystack.endIndex || !haystack[range.upperBound].isLetter
            if beforeOK && afterOK { return true }
            searchStart = range.upperBound
        }
        return false
    }

    static func containsAnyWord(_ haystack: String, _ phrases: [String]) -> Bool {
        phrases.contains { containsWord(haystack, $0) }
    }
}
