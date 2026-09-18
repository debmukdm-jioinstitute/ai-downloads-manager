import Foundation

struct ExpiryRecordDraft {
    var eventType: ExpiryEventType
    var title: String
    var category: String
    var date: Date
    var sourceText: String?
    var confidence: Double
    var isExplicit: Bool
    var isDerived: Bool
    var aiContext: String?
    var recurrence: String?
}

/// Purely local, offline heuristics that decide *what a detected date means*
/// — the expiry-vs-deadline-vs-event distinction the whole feature depends
/// on. Works without AI; AI (when enabled) refines on top of this, it never
/// replaces the ability to work without it.
enum ExpiryContextClassifier {

    // Longer/more specific phrases first so e.g. "valid until" beats a bare "valid".
    private static let keywordRules: [(patterns: [String], eventType: ExpiryEventType, confidence: Double)] = [
        (["date of expiry", "expiry date", "expiration date", "valid until", "valid through", "valid till", "expires on", "expires", "expiry:"], .expiry, 0.9),
        (["policy expiry", "coverage ends", "coverage end date", "end date"], .endDate, 0.85),
        (["payment due", "due date", "amount due", "due by", "last date for payment"], .dueDate, 0.85),
        (["submission deadline", "application deadline", "deadline", "last date", "closing date", "notice period", "termination notice"], .deadline, 0.8),
        (["renewal date", "renew by", "renewal window", "renews on", "next billing date", "next payment date"], .renewal, 0.8),
        (["valid from", "effective from", "issued on", "issue date", "date of issue", "policy start", "start date", "coverage begins", "coverage start"], .validFrom, 0.75),
        (["check-in", "check in", "departure", "flight date", "boarding", "event date", "appointment", "scheduled for", "travel date"], .eventDate, 0.75)
    ]

    private static let categoryKeywords: [(patterns: [String], category: String)] = [
        (["passport", "visa", "national id", "aadhaar", "identity card"], "Identity"),
        (["flight", "boarding", "itinerary", "hotel", "check-in", "check-out", "pnr", "e-ticket"], "Travel"),
        (["policy", "insurance", "coverage", "premium", "sum insured"], "Insurance"),
        (["subscription", "trial", "billing cycle", "auto-renew", "membership plan"], "Subscriptions"),
        (["contract", "agreement", "termination", "notice period"], "Contracts"),
        (["warranty", "guarantee period"], "Warranties"),
        (["certificate", "certification", "certified"], "Certificates"),
        (["license", "licence", "permit"], "Licenses"),
        (["membership", "member id"], "Memberships"),
        (["ticket", "event", "admission"], "Tickets"),
        (["coupon", "offer", "promo code", "discount valid"], "Offers"),
        (["invoice", "payment", "tax", "gst", "itr"], "Financial"),
        (["assignment", "submission", "application", "exam", "semester"], "Academic"),
        (["appointment", "meeting", "reservation"], "Appointments")
    ]

    static func classify(filename: String, text: String, ocrText: String?, fromOCR: Bool = false) -> [ExpiryRecordDraft] {
        var drafts: [ExpiryRecordDraft] = []
        // A scanned image (passport photo, insurance card) has no extracted
        // text at all, only OCR output — date-scanning must fall back to it,
        // the same way the caller's own pre-filter and `fromOCR` flag already
        // assume, or OCR-only documents silently never produce expiry records.
        let combined = text.isEmpty ? (ocrText ?? "") : text
        let fullLower = ((text) + " " + (ocrText ?? "")).lowercased()
        let category = category(forContext: fullLower, filename: filename)
        let recurrence = detectRecurrence(in: fullLower)

        let candidates = DateDetectionEngine.detectDates(in: combined)
        var handled: Set<Int> = []

        for i in candidates.indices {
            guard !handled.contains(i) else { continue }

            // "Policy Period: 01/04/2026 to 31/03/2027" style ranges: the spec's
            // own worked example treats the first date as the start and the
            // second as the expiry — a bare per-date keyword scan can't tell
            // these two dates apart since they share the same surrounding text.
            if i + 1 < candidates.count, isRangePair(candidates[i], candidates[i + 1], in: combined) {
                drafts.append(ExpiryRecordDraft(
                    eventType: .validFrom, title: title(for: .validFrom, category: category, filename: filename),
                    category: category, date: candidates[i].date, sourceText: candidates[i].context,
                    confidence: 0.85, isExplicit: true, isDerived: false, aiContext: nil, recurrence: recurrence
                ))
                drafts.append(ExpiryRecordDraft(
                    eventType: .expiry, title: title(for: .expiry, category: category, filename: filename),
                    category: category, date: candidates[i + 1].date, sourceText: candidates[i + 1].context,
                    confidence: 0.85, isExplicit: true, isDerived: false, aiContext: nil, recurrence: recurrence
                ))
                handled.insert(i); handled.insert(i + 1)
                continue
            }

            let candidate = candidates[i]
            let (eventType, confidence) = roleAndConfidence(forContext: candidate.context.lowercased())
            drafts.append(ExpiryRecordDraft(
                eventType: eventType,
                title: title(for: eventType, category: category, filename: filename),
                category: category,
                date: candidate.date,
                sourceText: candidate.context,
                confidence: confidence,
                isExplicit: true,
                isDerived: false,
                aiContext: nil,
                recurrence: recurrence
            ))
        }

        // "Valid for 12 months from the date of issue" — a derived expiry,
        // only added if we don't already have an explicit expiry from the
        // regular date scan (an explicit date always wins over a calculated one).
        if !drafts.contains(where: { $0.eventType == .expiry }),
           let duration = DateDetectionEngine.detectValidityDuration(in: combined) {
            let issueDate = candidates.first?.date ?? Date()
            if let derivedExpiry = Calendar.current.date(byAdding: .month, value: duration.months, to: issueDate) {
                drafts.append(ExpiryRecordDraft(
                    eventType: .expiry,
                    title: title(for: .expiry, category: category, filename: filename),
                    category: category,
                    date: derivedExpiry,
                    sourceText: String(combined[duration.range]),
                    confidence: 0.6,
                    isExplicit: false,
                    isDerived: true,
                    aiContext: "Calculated from a stated validity period, not an explicitly printed expiry date.",
                    recurrence: nil
                ))
            }
        }

        return drafts
    }

    private static func isRangePair(_ a: DetectedDateCandidate, _ b: DetectedDateCandidate, in text: String) -> Bool {
        guard a.range.upperBound <= b.range.lowerBound else { return false }
        let between = text[a.range.upperBound..<b.range.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard ["to", "-", "–", "through", "until"].contains(between) else { return false }
        let contextLower = (a.context + " " + b.context).lowercased()
        return ["period", "policy", "coverage", "valid"].contains { contextLower.contains($0) }
    }

    private static func roleAndConfidence(forContext context: String) -> (ExpiryEventType, Double) {
        for rule in keywordRules {
            if rule.patterns.contains(where: { context.contains($0) }) {
                return (rule.eventType, rule.confidence)
            }
        }
        // No keyword nearby at all — still worth surfacing, but low confidence
        // and defaulted to a generic deadline-ish bucket rather than guessing expiry.
        return (.eventDate, 0.35)
    }

    /// Used when converting an AI result, which gives a free-text
    /// `documentType` rather than one of our category strings.
    static func categoryGuess(forDocumentType documentType: String?, filename: String) -> String {
        let lower = ((documentType ?? "") + " " + filename).lowercased()
        for rule in categoryKeywords {
            if rule.patterns.contains(where: { lower.contains($0) }) {
                return rule.category
            }
        }
        return "Other"
    }

    private static func category(forContext context: String, filename: String) -> String {
        let lowerFilename = filename.lowercased()
        for rule in categoryKeywords {
            if rule.patterns.contains(where: { context.contains($0) || lowerFilename.contains($0) }) {
                return rule.category
            }
        }
        return "Other"
    }

    private static func title(for eventType: ExpiryEventType, category: String, filename: String) -> String {
        if category != "Other" { return category }
        let base = (filename as NSString).deletingPathExtension
        return base.isEmpty ? eventType.displayName : base
    }

    private static func detectRecurrence(in text: String) -> String? {
        if text.contains("monthly") || text.contains("every month") || text.contains("per month") { return "monthly" }
        if text.contains("annually") || text.contains("yearly") || text.contains("every year") || text.contains("per annum") { return "yearly" }
        if text.contains("quarterly") { return "quarterly" }
        if text.contains("weekly") { return "weekly" }
        return nil
    }
}
