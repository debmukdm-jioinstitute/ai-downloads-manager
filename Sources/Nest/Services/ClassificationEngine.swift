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

    static func classify(filename: String, fileExtension: String, extractedText: String?, ocrText: String?) -> LocalClassification {
        let lowerName = filename.lowercased()
        let text = ((extractedText ?? "") + " " + (ocrText ?? "")).lowercased()
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

        if containsAny(text, invoiceWords) || lowerName.contains("invoice") {
            return LocalClassification(category: "Finance", subcategory: "Invoices", tags: ["invoice"], vendor: extractVendor(from: text) ?? extractVendor(from: lowerName), documentType: "invoice", amount: extractAmount(from: text), currency: extractCurrency(from: text), confidence: 0.75, reason: "Text/filename contains invoice-related keywords.")
        }
        if containsAny(text, receiptWords) || lowerName.contains("receipt") {
            return LocalClassification(category: "Finance", subcategory: "Receipts", tags: ["receipt"], vendor: extractVendor(from: text) ?? extractVendor(from: lowerName), documentType: "receipt", amount: extractAmount(from: text), currency: extractCurrency(from: text), confidence: 0.7, reason: "Text/filename contains receipt-related keywords.")
        }
        if containsAny(text, statementWords) || lowerName.contains("statement") {
            return LocalClassification(category: "Finance", subcategory: "Statements", tags: ["statement"], vendor: extractVendor(from: text), documentType: "statement", amount: nil, currency: extractCurrency(from: text), confidence: 0.65, reason: "Text/filename contains bank/account statement keywords.")
        }
        if containsAny(text, taxWords) || lowerName.contains("tax") {
            return LocalClassification(category: "Finance", subcategory: "Tax Documents", tags: ["tax"], vendor: nil, documentType: "tax document", amount: nil, currency: nil, confidence: 0.6, reason: "Text/filename contains tax-related keywords.")
        }
        if containsAny(text, ticketWords) || lowerName.contains("ticket") || lowerName.contains("boarding") {
            return LocalClassification(category: "Personal", subcategory: "Tickets", tags: ["travel"], vendor: nil, documentType: "ticket", amount: nil, currency: nil, confidence: 0.7, reason: "Text/filename contains travel ticket keywords.")
        }
        if containsAny(text, assignmentWords) || lowerName.contains("assignment") {
            return LocalClassification(category: "Education", subcategory: "Assignments", tags: ["assignment"], vendor: nil, documentType: "assignment", amount: nil, currency: nil, confidence: 0.65, reason: "Text/filename contains assignment/homework keywords.")
        }
        if containsAny(text, researchWords) {
            return LocalClassification(category: "Education", subcategory: "Research Papers", tags: ["research"], vendor: nil, documentType: "research paper", amount: nil, currency: nil, confidence: 0.6, reason: "Text contains academic citation patterns.")
        }
        if containsAny(text, resumeWords) {
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
        needles.contains { haystack.contains($0) }
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
        let knownVendors = ["amazon", "flipkart", "reliance", "mckinsey", "uber", "ola", "swiggy", "zomato", "apple", "google", "microsoft", "netflix", "airtel", "jio", "irctc", "indigo", "makemytrip"]
        for vendor in knownVendors where text.contains(vendor) {
            return vendor.capitalized
        }
        return nil
    }
}
