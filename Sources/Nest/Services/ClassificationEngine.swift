import Foundation

/// Local, offline classification result. Used directly when AI is disabled,
/// and as the input/fallback when AI is enabled but fails or is low-confidence.
struct LocalClassification {
    var category: String
    var subcategory: String?
    var tags: [String]
    var vendor: String?
    var documentType: String?
    var amount: Double?
    var currency: String?
    var confidence: Double
    var reason: String
}

/// Pure filename + extracted-text heuristics. No network access, ever.
enum ClassificationEngine {

    private static let invoiceWords = ["invoice", "bill", "payment due", "amount due"]
    private static let receiptWords = ["receipt", "order confirmation", "thank you for your purchase"]
    private static let statementWords = ["statement", "account summary", "closing balance"]
    private static let taxWords = ["tax", "form 16", "itr", "1099", "w-2", "gst"]
    private static let assignmentWords = ["assignment", "homework", "problem set", "submission"]
    private static let researchWords = ["abstract", "references", "et al.", "doi:", "journal of"]
    private static let ticketWords = ["boarding pass", "e-ticket", "itinerary", "pnr", "confirmation number"]
    private static let resumeWords = ["curriculum vitae", "resume", "objective:"]
    private static let offerLetterWords = ["pleased to offer you", "we are pleased to offer", "offer letter", "letter of appointment", "date of joining", "terms of your employment", "your employment contract"]

    // Real invoices, receipts, statements, tax docs, and tickets always
    // declare themselves in their header/opening — that's a document
    // convention, not a heuristic guess. Scanning the full body (up to
    // 20,000 chars) for these phrases means one incidental mention deep in
    // an otherwise-unrelated long document (e.g. a resignation-recovery
    // clause saying "outstanding amount due" in a multi-page employment
    // contract) outweighs everything else and mislabels the whole file.
    // Windowing to the opening is both more accurate (matches where these
    // phrases actually mean what they say) and strictly cheaper to scan.
    private static let transactionalScanWindow = 2000

    static func classify(filename: String, fileExtension: String, extractedText: String?, ocrText: String?) -> LocalClassification {
        let lowerName = filename.lowercased()
        let fullText = ((extractedText ?? "") + " " + (ocrText ?? "")).lowercased()
        let text = String(fullText.prefix(transactionalScanWindow))
        let ext = fileExtension.lowercased()

        // Screenshots are near-certain from filename convention.
        if OCRService.imageExtensions.contains(ext) {
            if lowerName.hasPrefix("screenshot") || lowerName.hasPrefix("screen shot") || lowerName.contains("cleanshot") {
                return LocalClassification(category: "Images", subcategory: "Screenshots", tags: ["screenshot"], vendor: nil, documentType: "screenshot", amount: nil, currency: nil, confidence: 0.9, reason: "Filename matches screenshot naming convention.")
            }
            if !text.isEmpty && (containsAny(text, invoiceWords) || containsAny(text, receiptWords)) {
                return LocalClassification(category: "Images", subcategory: "Scanned Documents", tags: ["scan"], vendor: extractVendor(from: text), documentType: "scanned document", amount: extractAmount(from: text), currency: extractCurrency(from: text), confidence: 0.6, reason: "Image contains OCR text resembling a scanned financial document.")
            }
            return LocalClassification(category: "Images", subcategory: "Photos", tags: [], vendor: nil, documentType: "image", amount: nil, currency: nil, confidence: 0.4, reason: "No strong signal beyond file being an image; defaulting to Photos.")
        }

        if ext == "zip" {
            return LocalClassification(category: "Other", subcategory: "Uncategorized", tags: ["archive"], vendor: nil, documentType: "archive", amount: nil, currency: nil, confidence: 0.5, reason: "ZIP archives are not opened automatically; classify by filename only.")
        }

        // Checked before the financial categories on purpose: an offer
        // letter's defining phrases ("pleased to offer you", "date of
        // joining") are specific and unambiguous, whereas a generic phrase
        // like "amount due" is common boilerplate in employment contracts'
        // resignation/recovery clauses and should not be allowed to outrank
        // a document that has already clearly identified itself.
        if containsAny(text, offerLetterWords) {
            return LocalClassification(category: "Personal", subcategory: "Applications", tags: ["offer-letter"], vendor: nil, documentType: "offer letter", amount: nil, currency: nil, confidence: 0.8, reason: "Text contains offer-letter/employment-contract phrasing.")
        }
        if containsAny(text, invoiceWords) || TextMatching.containsWord(lowerName, "invoice") {
            return LocalClassification(category: "Finance", subcategory: "Invoices", tags: ["invoice"], vendor: extractVendor(from: fullText) ?? extractVendor(from: lowerName), documentType: "invoice", amount: extractAmount(from: fullText), currency: extractCurrency(from: fullText), confidence: 0.75, reason: "Text/filename contains invoice-related keywords.")
        }
        if containsAny(text, receiptWords) || TextMatching.containsWord(lowerName, "receipt") {
            return LocalClassification(category: "Finance", subcategory: "Receipts", tags: ["receipt"], vendor: extractVendor(from: fullText) ?? extractVendor(from: lowerName), documentType: "receipt", amount: extractAmount(from: fullText), currency: extractCurrency(from: fullText), confidence: 0.7, reason: "Text/filename contains receipt-related keywords.")
        }
        if containsAny(text, statementWords) || TextMatching.containsWord(lowerName, "statement") {
            return LocalClassification(category: "Finance", subcategory: "Statements", tags: ["statement"], vendor: extractVendor(from: fullText), documentType: "statement", amount: nil, currency: extractCurrency(from: fullText), confidence: 0.65, reason: "Text/filename contains bank/account statement keywords.")
        }
        if containsAny(text, taxWords) || TextMatching.containsWord(lowerName, "tax") {
            return LocalClassification(category: "Finance", subcategory: "Tax Documents", tags: ["tax"], vendor: nil, documentType: "tax document", amount: nil, currency: nil, confidence: 0.6, reason: "Text/filename contains tax-related keywords.")
        }
        if containsAny(text, ticketWords) || TextMatching.containsWord(lowerName, "ticket") || TextMatching.containsWord(lowerName, "boarding") {
            return LocalClassification(category: "Personal", subcategory: "Tickets", tags: ["travel"], vendor: nil, documentType: "ticket", amount: nil, currency: nil, confidence: 0.7, reason: "Text/filename contains travel ticket keywords.")
        }
        if containsAny(fullText, assignmentWords) || TextMatching.containsWord(lowerName, "assignment") {
            return LocalClassification(category: "Education", subcategory: "Assignments", tags: ["assignment"], vendor: nil, documentType: "assignment", amount: nil, currency: nil, confidence: 0.65, reason: "Text/filename contains assignment/homework keywords.")
        }
        if containsAny(fullText, researchWords) {
            return LocalClassification(category: "Education", subcategory: "Research Papers", tags: ["research"], vendor: nil, documentType: "research paper", amount: nil, currency: nil, confidence: 0.6, reason: "Text contains academic citation patterns.")
        }
        if containsAny(fullText, resumeWords) {
            return LocalClassification(category: "Personal", subcategory: "Applications", tags: ["resume"], vendor: nil, documentType: "resume", amount: nil, currency: nil, confidence: 0.6, reason: "Text contains resume/CV keywords.")
        }

        switch ext {
        case "ppt", "pptx", "key":
            return LocalClassification(category: "Work", subcategory: "Presentations", tags: [], vendor: nil, documentType: "presentation", amount: nil, currency: nil, confidence: 0.55, reason: "File extension indicates a presentation.")
        case "xls", "xlsx", "csv", "numbers":
            return LocalClassification(category: "Work", subcategory: "Spreadsheets", tags: [], vendor: nil, documentType: "spreadsheet", amount: nil, currency: nil, confidence: 0.5, reason: "File extension indicates a spreadsheet.")
        case "doc", "docx", "rtf", "pages":
            return LocalClassification(category: "Work", subcategory: "Documents", tags: [], vendor: nil, documentType: "document", amount: nil, currency: nil, confidence: 0.4, reason: "File extension indicates a generic document; no stronger signal found.")
        default:
            break
        }

        return LocalClassification(category: "Other", subcategory: "Uncategorized", tags: [], vendor: nil, documentType: nil, amount: nil, currency: nil, confidence: 0.2, reason: "No filename or content signal matched a known category.")
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        TextMatching.containsAnyWord(haystack, needles)
    }

    static func extractAmount(from text: String) -> Double? {
        let pattern = #"(?:₹|Rs\.?|INR|\$|USD)\s?([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), let numRange = Range(match.range(at: 1), in: text) else { return nil }
        let numString = text[numRange].replacingOccurrences(of: ",", with: "")
        return Double(numString)
    }

    static func extractCurrency(from text: String) -> String? {
        if text.contains("₹") || text.localizedCaseInsensitiveContains("INR") || text.localizedCaseInsensitiveContains("Rs.") { return "INR" }
        if text.contains("$") || text.localizedCaseInsensitiveContains("USD") { return "USD" }
        if text.contains("€") || text.localizedCaseInsensitiveContains("EUR") { return "EUR" }
        return nil
    }

    static func extractVendor(from text: String) -> String? {
        // Short names like "ola"/"jio" need word-boundary matching too, or
        // "Coca-Cola" and "enjoyment" would misattribute a vendor.
        let knownVendors = ["amazon", "flipkart", "reliance", "mckinsey", "uber", "ola", "swiggy", "zomato", "apple", "google", "microsoft", "netflix", "airtel", "jio", "irctc", "indigo", "makemytrip"]
        for vendor in knownVendors where TextMatching.containsWord(text, vendor) {
            return vendor.capitalized
        }
        return nil
    }
}
