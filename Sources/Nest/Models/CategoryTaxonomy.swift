import Foundation

/// Fixed category/subcategory taxonomy. AI and rule-based classification must only
/// ever choose values from this list — never invent new categories.
///
/// Modeled on what the document IS (a report vs. an invoice vs. a passport),
/// not on its file extension — a PDF, a DOCX, and a scanned JPG of the same
/// employment offer are all Career/Offer Letter. Extension-based browsing
/// still exists as its own orthogonal view (see FileTypeTaxonomy) for "show
/// me every spreadsheet regardless of what it's about."
enum CategoryTaxonomy {

    static let tree: [String: [String]] = [
        "Documents": ["General Document", "Report", "Contract", "Certificate", "Form", "Letter"],
        "Finance": ["Invoice", "Receipt", "Bank Statement", "Tax", "Investment", "Payment"],
        "Work": ["Presentation", "Meeting", "Project", "Report", "Spreadsheet"],
        "Education": ["Assignment", "Notes", "Research", "Lecture", "Certificate"],
        "Travel": ["Flight", "Hotel", "Visa", "Itinerary", "Boarding Pass"],
        "Identity": ["Passport", "Government ID", "Driving License", "PAN"],
        "Legal": ["Agreement", "Notice", "Affidavit", "Court Document"],
        "Career": ["Resume", "Cover Letter", "Offer Letter", "Experience Letter"],
        "Media": ["Photo", "Screenshot", "Video", "Audio"],
        "Code": ["Source Code", "Configuration", "Dataset"],
        "Archives": ["ZIP", "DMG", "Installer"],
        "Temporary": ["Cache", "Download", "Duplicate", "Unknown"],
        "Other": ["Uncategorized"]
    ]

    static let needsReview = "Needs Review"

    static var allCategories: [String] { Array(tree.keys).sorted() }

    static func subcategories(for category: String) -> [String] {
        tree[category] ?? []
    }

    static func isValid(category: String, subcategory: String?) -> Bool {
        guard let subs = tree[category] else { return false }
        guard let subcategory else { return true }
        return subs.contains(subcategory)
    }

    /// What a confidence score earns the file, from full automation down to
    /// not even guessing. Deliberately conservative: Nest never auto-*moves*
    /// a file regardless of tier (that always stays an explicit rule or user
    /// action — see FileOrganizerService), but the tier still governs how
    /// firmly a category gets stamped and whether the user gets a heads-up.
    enum ConfidenceAction {
        case autoOrganize       // 95-100%: confident enough to commit to fully
        case autoOrganizeNotify // 85-94%: commit to it, but flag it for a glance
        case confirm            // 70-84%: plausible, wants a human look
        case review             // 50-69%: genuinely unsure — Needs Review
        case untouched          // <50%: not enough evidence to claim anything
    }

    static func confidenceAction(for confidence: Double) -> ConfidenceAction {
        switch confidence {
        case 0.95...: return .autoOrganize
        case 0.85..<0.95: return .autoOrganizeNotify
        case 0.70..<0.85: return .confirm
        case 0.50..<0.70: return .review
        default: return .untouched
        }
    }

    /// Below this, `.review` and `.confirm` both land in the same "Needs
    /// Review" bucket in the UI today (Nest doesn't yet have a separate
    /// confirm-vs-review queue) — this is the single threshold that decides
    /// that split. Kept as one named constant so every call site (ingest,
    /// the reclassification self-heal) agrees on where the line is instead
    /// of each hardcoding 0.7.
    static let reviewConfidenceThreshold = 0.70
}
