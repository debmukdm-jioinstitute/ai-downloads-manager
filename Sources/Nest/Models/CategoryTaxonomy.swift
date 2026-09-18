import Foundation

/// Fixed category/subcategory taxonomy. AI and rule-based classification must only
/// ever choose values from this list — never invent new categories.
enum CategoryTaxonomy {

    static let tree: [String: [String]] = [
        "Work": ["Reports", "Presentations", "Documents", "Spreadsheets", "Meeting Materials"],
        "Finance": ["Invoices", "Receipts", "Bank Documents", "Statements", "Tax Documents"],
        "Education": ["Assignments", "Research Papers", "Lecture Material", "Case Studies", "Books"],
        "Personal": ["Travel", "Tickets", "Applications", "Personal Documents"],
        "Images": ["Screenshots", "Photos", "Scanned Documents", "Graphics"],
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

    /// Confidence below this threshold is routed to "Needs Review" instead of forced
    /// into a category, per product principle: never force every file into a bucket.
    static let reviewConfidenceThreshold = 0.55
}
