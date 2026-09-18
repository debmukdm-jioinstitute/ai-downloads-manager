import Foundation

/// Deterministic, offline parsing of common expiry-search phrasings into
/// structured filters. Works without AI — matches the app's "AI is optional"
/// principle. Full AI-assisted query interpretation is a documented future step.
struct ExpiryQueryFilter {
    var status: ExpiryUrgency?
    var category: String?
    var dateFrom: Date?
    var dateTo: Date?
    var freeText: String?
}

enum ExpiryQueryParser {
    static func parse(_ query: String, now: Date = Date()) -> ExpiryQueryFilter {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var filter = ExpiryQueryFilter()
        let calendar = Calendar.current

        if lower.contains("expired") {
            filter.status = .expired
        } else if lower.contains("critical") || lower.contains("urgent") {
            filter.status = .critical
        } else if lower.contains("soon") {
            filter.status = .soon
        }

        if let range = dateRange(in: lower, now: now, calendar: calendar) {
            filter.dateFrom = range.0
            filter.dateTo = range.1
        }

        for category in ExpiryCategoryTaxonomy.suggested where lower.contains(category.lowercased()) {
            filter.category = category
        }
        // Common synonyms that don't literally match a category name.
        if lower.contains("visa") || lower.contains("passport") { filter.category = "Identity" }
        if lower.contains("subscription") || lower.contains("renew") { filter.category = filter.category ?? "Subscriptions" }
        if lower.contains("policy") || lower.contains("insurance") { filter.category = "Insurance" }
        if lower.contains("travel") || lower.contains("flight") || lower.contains("hotel") { filter.category = "Travel" }

        // Whatever's left after stripping recognized phrases is treated as a
        // plain-text filter against the record title/source text.
        let stripped = strip(knownPhrases, from: lower)
        let remaining = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty { filter.freeText = remaining }

        return filter
    }

    private static let knownPhrases = [
        "what expires", "which documents expire", "expiring", "expires", "expired",
        "this month", "this week", "next 30 days", "next 7 days", "next 90 days",
        "within 30 days", "within 7 days", "within 90 days", "next month",
        "show me all", "show me", "do i have any", "needs attention", "everything related to",
        "that has a deadline", "renew next month", "renews next month"
    ]

    private static func strip(_ phrases: [String], from text: String) -> String {
        var result = text
        for phrase in phrases {
            result = result.replacingOccurrences(of: phrase, with: "")
        }
        return result
    }

    private static func dateRange(in text: String, now: Date, calendar: Calendar) -> (Date, Date)? {
        if text.contains("this week") {
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return (start, end)
        }
        if text.contains("this month") {
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        }
        if text.contains("next month") {
            let start = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .month, value: 2, to: calendar.startOfDay(for: now))!
            return (start, end)
        }
        for days in [7, 30, 90] {
            if text.contains("next \(days) days") || text.contains("within \(days) days") {
                let start = calendar.startOfDay(for: now)
                let end = calendar.date(byAdding: .day, value: days, to: start)!
                return (start, end)
            }
        }
        return nil
    }
}
