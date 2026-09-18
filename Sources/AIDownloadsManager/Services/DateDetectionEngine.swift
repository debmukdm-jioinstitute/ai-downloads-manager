import Foundation

struct DetectedDateCandidate {
    var date: Date
    var rawText: String
    var range: Range<String.Index>
    var context: String // ~80 chars around the match, for keyword classification and "Why?" display
}

/// Finds every date-shaped substring in a block of text using explicit,
/// deterministic regexes rather than NSDataDetector.
///
/// This is a deliberate choice, not an oversight: NSDataDetector mis-parses
/// exactly the phrasing this feature depends on most — "valid until 31 March
/// 2027" and "passport valid until: 12 March 2027" both got silently resolved
/// to *today's date* (it interprets "until"/"through" + a date as a relative
/// duration expression), and "Policy Period: 01/04/2026 to 31/03/2027"
/// collapsed to a single match that dropped the end date — the expiry date —
/// entirely. Both were verified empirically before writing this. Regexes are
/// slightly more code, but they're deterministic, their match range is
/// exactly the date substring (clean "source text" for the Why? explanation),
/// and they were verified against every format the spec lists.
enum DateDetectionEngine {

    private static let contextRadius = 70

    private static let monthNames = [
        "january", "february", "march", "april", "may", "june", "july",
        "august", "september", "october", "november", "december",
        "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "sept", "oct", "nov", "dec"
    ]
    private static let monthIndex: [String: Int] = [
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
        "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12
    ]
    private static let monthAlternation = monthNames.joined(separator: "|")

    private static let isoRegex = try! NSRegularExpression(pattern: #"\b(\d{4})-(\d{2})-(\d{2})\b"#)
    private static let numericRegex = try! NSRegularExpression(pattern: #"\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b"#)
    private static let monthDayYearRegex = try! NSRegularExpression(pattern: "\\b(\(monthAlternation))\\.?\\s+(\\d{1,2}),?\\s+(\\d{4})\\b", options: [.caseInsensitive])
    private static let dayMonthYearRegex = try! NSRegularExpression(pattern: "\\b(\\d{1,2})\\s+(\(monthAlternation))\\.?,?\\s+(\\d{4})\\b", options: [.caseInsensitive])

    static func detectDates(in text: String) -> [DetectedDateCandidate] {
        guard !text.isEmpty else { return [] }
        let nsText = text as NSString
        var seenRanges: [NSRange] = []
        var results: [DetectedDateCandidate] = []

        func run(_ regex: NSRegularExpression, parse: (NSTextCheckingResult, NSString) -> Date?) {
            for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                // Skip if this overlaps a date we've already captured (regexes can overlap, e.g. ISO inside a longer match).
                guard !seenRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { continue }
                guard let date = parse(match, nsText), let range = Range(match.range, in: text) else { continue }
                seenRanges.append(match.range)
                let raw = nsText.substring(with: match.range)
                results.append(DetectedDateCandidate(date: date, rawText: raw, range: range, context: extractContext(text: text, around: range)))
            }
        }

        run(isoRegex) { match, ns in
            guard let y = Int(ns.substring(with: match.range(at: 1))),
                  let m = Int(ns.substring(with: match.range(at: 2))),
                  let d = Int(ns.substring(with: match.range(at: 3))) else { return nil }
            return makeDate(day: d, month: m, year: y)
        }
        run(monthDayYearRegex) { match, ns in
            let monthName = ns.substring(with: match.range(at: 1)).lowercased()
            guard let month = monthIndex[monthName],
                  let day = Int(ns.substring(with: match.range(at: 2))),
                  let year = Int(ns.substring(with: match.range(at: 3))) else { return nil }
            return makeDate(day: day, month: month, year: year)
        }
        run(dayMonthYearRegex) { match, ns in
            guard let day = Int(ns.substring(with: match.range(at: 1))) else { return nil }
            let monthName = ns.substring(with: match.range(at: 2)).lowercased()
            guard let month = monthIndex[monthName],
                  let year = Int(ns.substring(with: match.range(at: 3))) else { return nil }
            return makeDate(day: day, month: month, year: year)
        }
        run(numericRegex) { match, ns in
            guard let a = Int(ns.substring(with: match.range(at: 1))),
                  let b = Int(ns.substring(with: match.range(at: 2))),
                  var year = Int(ns.substring(with: match.range(at: 3))) else { return nil }
            if year < 100 { year = year < 70 ? 2000 + year : 1900 + year }
            // Disambiguate day/month order: if the first number can't be a
            // month, it's day-first; if the second can't be, it's US
            // month-first; otherwise default to day-first (international).
            let day: Int, month: Int
            if a > 12 { day = a; month = b }
            else if b > 12 { month = a; day = b }
            else { day = a; month = b }
            return makeDate(day: day, month: month, year: year)
        }

        return results.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// "Valid for 12 months from the date of issue" style phrases. Returns the
    /// number of months/years and the range of the phrase so the caller can
    /// look for a nearby issue date to add the duration to.
    static func detectValidityDuration(in text: String) -> (range: Range<String.Index>, months: Int)? {
        let pattern = #"valid\s+for\s+(\d{1,3})\s+(month|months|year|years)\s+from"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              let numberRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let fullRange = Range(match.range, in: text),
              let number = Int(text[numberRange]) else { return nil }
        let unit = text[unitRange].lowercased()
        let months = unit.hasPrefix("year") ? number * 12 : number
        return (fullRange, months)
    }

    private static let gregorian = Calendar(identifier: .gregorian)

    /// `Calendar.date(from:)` silently rolls invalid day-in-month combos
    /// forward instead of rejecting them (verified: Feb 30 2027 -> Mar 2
    /// 2027, Apr 31 2027 -> May 1 2027) — an OCR misread or typo like
    /// "30/02/2027" must not become a confidently-wrong expiry date, so the
    /// result is round-tripped back through the calendar and rejected unless
    /// it reproduces the exact day/month/year requested.
    private static func makeDate(day: Int, month: Int, year: Int) -> Date? {
        guard month >= 1, month <= 12, day >= 1, day <= 31 else { return nil }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        guard let date = gregorian.date(from: components) else { return nil }
        let roundTrip = gregorian.dateComponents([.day, .month, .year], from: date)
        guard roundTrip.day == day, roundTrip.month == month, roundTrip.year == year else { return nil }
        return date
    }

    private static func extractContext(text: String, around range: Range<String.Index>) -> String {
        let start = text.index(range.lowerBound, offsetBy: -contextRadius, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: contextRadius, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
