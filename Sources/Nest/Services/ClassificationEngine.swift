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

/// A single document type's detection rule: one *anchor* concept the
/// document must declare itself with (checked in filename OR text), plus
/// independent *support* concepts that corroborate it.
///
/// This exists because single-keyword matching is exactly what caused every
/// real misclassification found this session: "amount due" alone tagged an
/// employment contract as an invoice; "coverage" alone (as in "analyst
/// coverage") tagged a stock research report as insurance. Requiring BOTH an
/// explicit self-declaration AND independent structural corroboration before
/// awarding high confidence is what a human skimming the document actually
/// does — nobody calls a document an invoice because it mentions money once.
private struct DocumentRule {
    let category: String
    let subcategory: String
    let documentType: String
    let tag: String
    /// At least one of these must appear — the document naming what it is.
    let anchors: [String]
    /// Each inner array is one independent piece of corroborating evidence
    /// (satisfied if any phrase in it matches); `nil` inner array means "an
    /// amount was found" rather than a phrase.
    let supportGroups: [[String]?]
    let minSupportForHighConfidence: Int
    let baseConfidence: Double
    let highConfidence: Double
    /// Anchor phrases are checked in this text window; support phrases
    /// always search the full document (a receipt's transaction date isn't
    /// necessarily in its first 2000 characters).
    let anchorInFullText: Bool
}

/// Pure filename + extracted-text heuristics. No network access, ever.
enum ClassificationEngine {

    // Real invoices/receipts/statements/tickets/passports all declare
    // themselves in their header by convention — scanning the whole body
    // (up to 20,000 chars) for a declaring phrase only invites incidental
    // collisions from unrelated later content (a resignation clause saying
    // "amount due" deep in an employment contract), and costs more to scan.
    private static let anchorScanWindow = 2000

    private static let documentRules: [DocumentRule] = [
        // --- Career (checked early: an offer letter mentioning "amount due"
        // in a recovery clause must not fall through to Finance below it) ---
        DocumentRule(category: "Career", subcategory: "Offer Letter", documentType: "offer letter", tag: "offer-letter",
                     anchors: ["pleased to offer you", "we are pleased to offer", "offer letter", "letter of appointment"],
                     supportGroups: [["date of joining"], ["compensation", "ctc", "salary", "remuneration"], ["designation", "position"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.75, highConfidence: 0.88, anchorInFullText: false),
        DocumentRule(category: "Career", subcategory: "Experience Letter", documentType: "experience letter", tag: "experience-letter",
                     anchors: ["experience letter", "relieving letter", "to whomsoever it may concern"],
                     supportGroups: [["employment period", "last working day", "date of joining"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.65, highConfidence: 0.8, anchorInFullText: false),
        DocumentRule(category: "Career", subcategory: "Cover Letter", documentType: "cover letter", tag: "cover-letter",
                     anchors: ["cover letter", "dear hiring manager", "i am writing to apply"],
                     supportGroups: [["position", "role", "opportunity"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.78, anchorInFullText: false),
        DocumentRule(category: "Career", subcategory: "Resume", documentType: "resume", tag: "resume",
                     anchors: ["curriculum vitae", "resume"],
                     supportGroups: [["work experience", "professional experience", "employment history"], ["education"], ["skills"]],
                     minSupportForHighConfidence: 2, baseConfidence: 0.55, highConfidence: 0.85, anchorInFullText: true),

        // --- Identity ---
        DocumentRule(category: "Identity", subcategory: "Passport", documentType: "passport", tag: "passport",
                     anchors: ["passport number", "passport no"],
                     supportGroups: [["nationality"], ["date of birth", "dob"], ["date of expiry", "expiry date"]],
                     minSupportForHighConfidence: 2, baseConfidence: 0.6, highConfidence: 0.9, anchorInFullText: true),
        DocumentRule(category: "Identity", subcategory: "Driving License", documentType: "driving license", tag: "driving-license",
                     anchors: ["driving licence", "driving license", "driver's license"],
                     supportGroups: [["vehicle class", "license number", "licence number"], ["date of issue"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.65, highConfidence: 0.85, anchorInFullText: true),
        // "permanent account number" alone is a weak signal — it's a field
        // requested on countless tax/finance forms, not just an actual PAN
        // card scan ("A.Y. 2024-25.pdf", an ITR filing, was misfiled as a
        // PAN card this way). Require the card's own header structure too.
        DocumentRule(category: "Identity", subcategory: "PAN", documentType: "PAN card", tag: "pan",
                     anchors: ["pan card", "income tax department"],
                     supportGroups: [["permanent account number"], ["date of birth", "father's name", "father name"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.5, highConfidence: 0.78, anchorInFullText: true),
        DocumentRule(category: "Identity", subcategory: "Government ID", documentType: "government ID", tag: "government-id",
                     anchors: ["aadhaar", "national identity card", "voter id", "government of india"],
                     supportGroups: [], minSupportForHighConfidence: 0, baseConfidence: 0.65, highConfidence: 0.65, anchorInFullText: true),

        // --- Travel (Boarding Pass before the more generic Flight rule) ---
        DocumentRule(category: "Travel", subcategory: "Boarding Pass", documentType: "boarding pass", tag: "boarding-pass",
                     anchors: ["boarding pass", "boarding group"],
                     supportGroups: [["seat"], ["gate"], ["pnr", "flight number", "flight no"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.7, highConfidence: 0.88, anchorInFullText: true),
        DocumentRule(category: "Travel", subcategory: "Flight", documentType: "flight ticket", tag: "flight",
                     anchors: ["e-ticket", "flight ticket", "pnr", "confirmation number"],
                     supportGroups: [["airline"], ["departure", "arrival"], ["passenger"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.82, anchorInFullText: true),
        DocumentRule(category: "Travel", subcategory: "Itinerary", documentType: "itinerary", tag: "itinerary",
                     anchors: ["itinerary"],
                     supportGroups: [["day 1", "segment", "layover"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.75, anchorInFullText: true),
        DocumentRule(category: "Travel", subcategory: "Hotel", documentType: "hotel reservation", tag: "hotel",
                     anchors: ["hotel reservation", "booking confirmation", "reservation number"],
                     supportGroups: [["check-in", "check-out"], ["guest name", "guest"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.8, anchorInFullText: true),
        // "visa" alone collides with Visa the card network — require an
        // identity-document-flavored support signal before trusting it.
        DocumentRule(category: "Travel", subcategory: "Visa", documentType: "visa", tag: "visa",
                     anchors: ["tourist visa", "visa number", "visa application"],
                     supportGroups: [["passport number"], ["validity", "valid until"], ["country of issue"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.82, anchorInFullText: true),

        // --- Finance ---
        DocumentRule(category: "Finance", subcategory: "Invoice", documentType: "invoice", tag: "invoice",
                     anchors: ["invoice", "invoice number", "invoice no", "invoice date"],
                     supportGroups: [["tax", "gst", "vat"], ["subtotal", "line item"], nil],
                     minSupportForHighConfidence: 1, baseConfidence: 0.65, highConfidence: 0.85, anchorInFullText: false),
        DocumentRule(category: "Finance", subcategory: "Receipt", documentType: "receipt", tag: "receipt",
                     anchors: ["receipt", "order confirmation", "thank you for your purchase"],
                     supportGroups: [["merchant", "purchased"], ["transaction date", "date of purchase"], nil],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.8, anchorInFullText: false),
        // "statement" alone is too generic (an annual report's "financial
        // statements" section triggered this before) — require the compound
        // phrase, not the bare word.
        DocumentRule(category: "Finance", subcategory: "Bank Statement", documentType: "bank statement", tag: "bank-statement",
                     anchors: ["bank statement", "account statement", "statement of account"],
                     supportGroups: [["account number"], ["opening balance", "closing balance"], ["transaction"]],
                     minSupportForHighConfidence: 2, baseConfidence: 0.6, highConfidence: 0.85, anchorInFullText: false),
        DocumentRule(category: "Finance", subcategory: "Tax", documentType: "tax document", tag: "tax",
                     anchors: ["form 16", "income tax return", "itr", "gst return", "1099", "w-2"],
                     supportGroups: [["assessment year", "financial year"], ["tax deducted", "tds"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.65, highConfidence: 0.8, anchorInFullText: true),
        DocumentRule(category: "Finance", subcategory: "Investment", documentType: "investment statement", tag: "investment",
                     anchors: ["mutual fund", "folio number", "portfolio statement", "demat account"],
                     supportGroups: [["units", "sip", "nav"], ["stocks", "equity", "holdings"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.55, highConfidence: 0.78, anchorInFullText: true),
        DocumentRule(category: "Finance", subcategory: "Payment", documentType: "payment confirmation", tag: "payment",
                     anchors: ["payment confirmation", "payment successful", "transaction id"],
                     supportGroups: [nil],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.78, anchorInFullText: false),

        // --- Education ---
        DocumentRule(category: "Education", subcategory: "Assignment", documentType: "assignment", tag: "assignment",
                     anchors: ["assignment", "homework", "problem set"],
                     supportGroups: [["question 1", "instructions:", "answer the following"], ["submission", "due date"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.55, highConfidence: 0.8, anchorInFullText: false),
        DocumentRule(category: "Education", subcategory: "Research", documentType: "research paper", tag: "research",
                     anchors: ["abstract", "et al.", "doi:", "journal of"],
                     supportGroups: [["methodology"], ["references", "bibliography"], ["literature review"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.55, highConfidence: 0.8, anchorInFullText: true),
        DocumentRule(category: "Education", subcategory: "Lecture", documentType: "lecture material", tag: "lecture",
                     anchors: ["lecture notes", "lecture slides", "course outline"],
                     supportGroups: [["module", "unit", "chapter"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.55, highConfidence: 0.7, anchorInFullText: true),

        // --- Work ---
        DocumentRule(category: "Work", subcategory: "Meeting", documentType: "meeting notes", tag: "meeting",
                     anchors: ["meeting minutes", "meeting notes", "agenda"],
                     supportGroups: [["attendees", "present:"], ["action item", "action items"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.55, highConfidence: 0.8, anchorInFullText: false),

        // --- Legal (checked after Career/Offer Letter so an employment
        // contract's "agree to the terms" language doesn't outrank the much
        // more specific offer-letter phrasing already matched above) ---
        DocumentRule(category: "Legal", subcategory: "Agreement", documentType: "legal agreement", tag: "agreement",
                     anchors: ["this agreement", "memorandum of understanding", "hereby agree"],
                     supportGroups: [["party of the first part", "witnesseth", "parties hereto"], ["signature", "signed by"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.55, highConfidence: 0.8, anchorInFullText: true),
        DocumentRule(category: "Legal", subcategory: "Notice", documentType: "legal notice", tag: "legal-notice",
                     anchors: ["legal notice", "cease and desist", "notice is hereby given"],
                     supportGroups: [], minSupportForHighConfidence: 0, baseConfidence: 0.65, highConfidence: 0.65, anchorInFullText: true),
        DocumentRule(category: "Legal", subcategory: "Affidavit", documentType: "affidavit", tag: "affidavit",
                     anchors: ["affidavit", "i do solemnly affirm", "sworn statement"],
                     supportGroups: [["notary", "notarized", "before me"], ["deponent"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.82, anchorInFullText: true),
        DocumentRule(category: "Legal", subcategory: "Court Document", documentType: "court document", tag: "court-document",
                     anchors: ["in the court of", "petitioner", "respondent"],
                     supportGroups: [["case no", "case number"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.8, anchorInFullText: true),

        // --- Generic documents (checked last, on purpose: every rule above
        // is more specific than "this is a contract" or "this is a letter") ---
        DocumentRule(category: "Documents", subcategory: "Contract", documentType: "contract", tag: "contract",
                     anchors: ["contract"],
                     supportGroups: [], minSupportForHighConfidence: 0, baseConfidence: 0.5, highConfidence: 0.5, anchorInFullText: true),
        DocumentRule(category: "Documents", subcategory: "Form", documentType: "form", tag: "form",
                     anchors: ["application form", "please fill", "form no."],
                     supportGroups: [], minSupportForHighConfidence: 0, baseConfidence: 0.55, highConfidence: 0.55, anchorInFullText: true),
        // Bare "certification" is too generic — annual reports and research
        // disclaimers use it in compliance/audit boilerplate ("Infosys
        // annual report" was misfiled as a Certificate this way, matching
        // "certification" + an "issued by" mention in its auditor section).
        DocumentRule(category: "Documents", subcategory: "Certificate", documentType: "certificate", tag: "certificate",
                     anchors: ["certificate of completion", "this is to certify"],
                     supportGroups: [["issued by", "issuing authority"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.6, highConfidence: 0.78, anchorInFullText: true),
        DocumentRule(category: "Documents", subcategory: "Letter", documentType: "letter", tag: "letter",
                     anchors: ["dear sir", "dear madam", "yours sincerely", "yours faithfully"],
                     supportGroups: [], minSupportForHighConfidence: 0, baseConfidence: 0.5, highConfidence: 0.5, anchorInFullText: true),
        DocumentRule(category: "Work", subcategory: "Report", documentType: "report", tag: "report",
                     anchors: ["executive summary", "findings", "conclusions and recommendations"],
                     supportGroups: [["methodology"], ["figure", "chart", "table"]],
                     minSupportForHighConfidence: 1, baseConfidence: 0.5, highConfidence: 0.7, anchorInFullText: true)
    ]

    static func classify(filename: String, fileExtension: String, extractedText: String?, ocrText: String?) -> LocalClassification {
        let lowerName = filename.lowercased()
        let fullText = ((extractedText ?? "") + " " + (ocrText ?? "")).lowercased()
        let headerText = String(fullText.prefix(anchorScanWindow))
        let ext = fileExtension.lowercased()

        // Screenshots are near-certain from filename convention.
        if OCRService.imageExtensions.contains(ext) {
            if lowerName.hasPrefix("screenshot") || lowerName.hasPrefix("screen shot") || lowerName.contains("cleanshot") {
                return LocalClassification(category: "Media", subcategory: "Screenshot", tags: ["screenshot"], vendor: nil, documentType: "screenshot", amount: nil, currency: nil, confidence: 0.9, reason: "Filename matches screenshot naming convention.")
            }
            if !fullText.isEmpty, let scan = matchDocumentRules(headerText: headerText, fullText: fullText, lowerName: lowerName) {
                return scan
            }
            return LocalClassification(category: "Media", subcategory: "Photo", tags: [], vendor: nil, documentType: "image", amount: nil, currency: nil, confidence: 0.4, reason: "No strong signal beyond file being an image; defaulting to Photo.")
        }

        if ["zip", "tar", "gz", "rar", "7z"].contains(ext) {
            return LocalClassification(category: "Archives", subcategory: "ZIP", tags: ["archive"], vendor: nil, documentType: "archive", amount: nil, currency: nil, confidence: 0.5, reason: "Archive file; contents are not opened automatically.")
        }
        if ext == "dmg" {
            return LocalClassification(category: "Archives", subcategory: "DMG", tags: ["archive"], vendor: nil, documentType: "disk image", amount: nil, currency: nil, confidence: 0.6, reason: "macOS disk image.")
        }
        if ext == "pkg" {
            return LocalClassification(category: "Archives", subcategory: "Installer", tags: ["archive"], vendor: nil, documentType: "installer package", amount: nil, currency: nil, confidence: 0.6, reason: "macOS installer package.")
        }
        if ["mp3", "wav", "flac", "m4a", "aac"].contains(ext) {
            return LocalClassification(category: "Media", subcategory: "Audio", tags: [], vendor: nil, documentType: "audio", amount: nil, currency: nil, confidence: 0.5, reason: "File extension indicates audio.")
        }
        if ["mp4", "mov", "avi", "mkv", "webm"].contains(ext) {
            return LocalClassification(category: "Media", subcategory: "Video", tags: [], vendor: nil, documentType: "video", amount: nil, currency: nil, confidence: 0.5, reason: "File extension indicates video.")
        }

        if let matched = matchDocumentRules(headerText: headerText, fullText: fullText, lowerName: lowerName) {
            return matched
        }

        switch ext {
        case "ppt", "pptx", "key":
            return LocalClassification(category: "Work", subcategory: "Presentation", tags: [], vendor: nil, documentType: "presentation", amount: nil, currency: nil, confidence: 0.55, reason: "File extension indicates a presentation.")
        case "json", "yaml", "yml":
            return LocalClassification(category: "Code", subcategory: "Configuration", tags: [], vendor: nil, documentType: "configuration file", amount: nil, currency: nil, confidence: 0.55, reason: "File extension indicates a configuration file.")
        case "swift", "py", "js", "ts", "tsx", "jsx", "go", "rs", "java", "kt", "c", "h", "cpp", "hpp", "cs", "rb", "php", "sh", "sql":
            return LocalClassification(category: "Code", subcategory: "Source Code", tags: [], vendor: nil, documentType: "source code", amount: nil, currency: nil, confidence: 0.6, reason: "File extension indicates source code.")
        case "xls", "xlsx", "csv", "tsv", "numbers":
            return LocalClassification(category: "Work", subcategory: "Spreadsheet", tags: [], vendor: nil, documentType: "spreadsheet", amount: nil, currency: nil, confidence: 0.5, reason: "File extension indicates a spreadsheet.")
        case "doc", "docx", "rtf", "pages", "txt", "md", "html", "htm":
            return LocalClassification(category: "Documents", subcategory: "General Document", tags: [], vendor: nil, documentType: "document", amount: nil, currency: nil, confidence: 0.4, reason: "File extension indicates a generic document; no stronger signal found.")
        default:
            break
        }

        return LocalClassification(category: "Other", subcategory: "Uncategorized", tags: [], vendor: nil, documentType: nil, amount: nil, currency: nil, confidence: 0.2, reason: "No filename or content signal matched a known category.")
    }

    /// Evaluates every rule in priority order (declaration order in
    /// `documentRules`) and returns the first whose anchor is present. Only
    /// one rule can ever fire per document — the first, most-specific match
    /// wins, matching how the rules are deliberately ordered above.
    private static func matchDocumentRules(headerText: String, fullText: String, lowerName: String) -> LocalClassification? {
        for rule in documentRules {
            let searchText = rule.anchorInFullText ? fullText : headerText
            let anchorHit = rule.anchors.contains { TextMatching.containsWord(searchText, $0) || TextMatching.containsWord(lowerName, $0) }
            guard anchorHit else { continue }

            var supportCount = 0
            for group in rule.supportGroups {
                if let group {
                    if group.contains(where: { TextMatching.containsWord(fullText, $0) }) { supportCount += 1 }
                } else if extractAmount(from: fullText) != nil {
                    supportCount += 1
                }
            }
            let confidence = supportCount >= rule.minSupportForHighConfidence ? rule.highConfidence : rule.baseConfidence

            let isFinancial = rule.category == "Finance"
            return LocalClassification(
                category: rule.category,
                subcategory: rule.subcategory,
                tags: [rule.tag],
                vendor: isFinancial ? (extractVendor(from: fullText) ?? extractVendor(from: lowerName)) : nil,
                documentType: rule.documentType,
                amount: isFinancial ? extractAmount(from: fullText) : nil,
                currency: isFinancial ? extractCurrency(from: fullText) : nil,
                confidence: confidence,
                reason: "Matched \"\(rule.anchors.first { TextMatching.containsWord(searchText, $0) || TextMatching.containsWord(lowerName, $0) } ?? rule.anchors[0])\" with \(supportCount) supporting signal\(supportCount == 1 ? "" : "s")."
            )
        }
        return nil
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
