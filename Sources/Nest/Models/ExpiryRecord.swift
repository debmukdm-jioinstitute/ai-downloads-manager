import Foundation

/// The semantic role a detected date plays. This is the core distinction the
/// whole feature rests on: a flight date is an EVENT_DATE, not an EXPIRY —
/// conflating them is exactly the mistake this model exists to avoid.
enum ExpiryEventType: String, Codable, CaseIterable {
    case expiry = "EXPIRY"
    case deadline = "DEADLINE"
    case renewal = "RENEWAL"
    case dueDate = "DUE_DATE"
    case eventDate = "EVENT_DATE"
    case startDate = "START_DATE"
    case endDate = "END_DATE"
    case validFrom = "VALID_FROM"
    case validUntil = "VALID_UNTIL"

    var displayName: String {
        switch self {
        case .expiry: return "Expiry"
        case .deadline: return "Deadline"
        case .renewal: return "Renewal"
        case .dueDate: return "Due Date"
        case .eventDate: return "Event"
        case .startDate: return "Start Date"
        case .endDate: return "End Date"
        case .validFrom: return "Valid From"
        case .validUntil: return "Valid Until"
        }
    }

    /// Whether this event type should ever appear in the Expiry Center's
    /// urgency buckets (Expired/Soon/Upcoming). Plain informational dates
    /// like an event's start don't decay into "urgency" the way an expiry does.
    var isTimeSensitive: Bool {
        switch self {
        case .expiry, .deadline, .renewal, .dueDate, .validUntil, .endDate: return true
        case .eventDate, .startDate, .validFrom: return false
        }
    }
}

/// A user (or system) action that overrides whatever the computed urgency
/// would otherwise be — e.g. the user already renewed, so it's done, not expired.
enum ExpiryUserStatus: String, Codable {
    case active
    case completed
    case ignored
}

/// Computed from today vs. the record's date. Never persisted stale — always
/// recalculated, so it can't silently drift out of date.
enum ExpiryUrgency: String, Codable, CaseIterable, Hashable {
    case expired
    case critical
    case soon
    case upcoming
    case future
}

/// Suggested category taxonomy for expiry/deadline documents. Unlike
/// `CategoryTaxonomy` for file organization, this is intentionally NOT a
/// closed, validated list — the spec calls for an extensible taxonomy, so any
/// string is a valid category and this is just what's offered in filter UIs
/// and what local heuristics reach for first.
enum ExpiryCategoryTaxonomy {
    static let suggested: [String] = [
        "Identity", "Travel", "Insurance", "Subscriptions", "Contracts",
        "Warranties", "Certificates", "Licenses", "Memberships", "Tickets",
        "Offers", "Financial", "Academic", "Appointments", "Other"
    ]
}

/// One detected date-event inside a document. A single document can produce
/// several of these (issue date, start date, expiry date, payment due, ...).
final class ExpiryRecord: Codable, Identifiable {
    let id: UUID
    var documentID: UUID
    var documentFilename: String

    var eventType: ExpiryEventType
    var title: String
    var category: String
    var date: Date

    var sourceText: String?
    var sourcePage: Int?
    var fromOCR: Bool

    var confidence: Double
    /// True if the document states this date outright; false if the app
    /// calculated it (e.g. "valid for 12 months from issue date").
    var isExplicit: Bool
    var isDerived: Bool

    var userStatus: ExpiryUserStatus
    var aiContext: String?

    var reminderEnabled: Bool
    var reminderDate: Date?
    var calendarEventIdentifier: String?

    /// Best-effort only, e.g. "monthly"/"yearly" — nil when the document
    /// doesn't clearly establish a recurrence.
    var recurrence: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        documentID: UUID,
        documentFilename: String,
        eventType: ExpiryEventType,
        title: String,
        category: String,
        date: Date,
        sourceText: String?,
        sourcePage: Int? = nil,
        fromOCR: Bool = false,
        confidence: Double,
        isExplicit: Bool,
        isDerived: Bool = false,
        aiContext: String? = nil,
        recurrence: String? = nil
    ) {
        self.id = UUID()
        self.documentID = documentID
        self.documentFilename = documentFilename
        self.eventType = eventType
        self.title = title
        self.category = category
        self.date = date
        self.sourceText = sourceText
        self.sourcePage = sourcePage
        self.fromOCR = fromOCR
        self.confidence = confidence
        self.isExplicit = isExplicit
        self.isDerived = isDerived
        self.userStatus = .active
        self.aiContext = aiContext
        self.reminderEnabled = false
        self.reminderDate = nil
        self.recurrence = recurrence
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Confidence below this is never surfaced as a confident reminder — it
    /// lands in "Needs Review" instead, per the "never claim from ambiguous
    /// text" safety rule.
    static let reviewConfidenceThreshold = 0.75

    var needsReview: Bool {
        userStatus == .active && confidence < Self.reviewConfidenceThreshold
    }

    func urgency(now: Date = Date(), windows: ExpiryUrgencyWindows = .default) -> ExpiryUrgency? {
        guard eventType.isTimeSensitive, userStatus == .active else { return nil }
        return ExpiryUrgencyCalculator.urgency(for: date, windows: windows, now: now)
    }

    func daysRemaining(now: Date = Date()) -> Int {
        ExpiryUrgencyCalculator.daysRemaining(until: date, now: now)
    }
}
