import Foundation

/// A user-defined automation rule, e.g. "Finance/Invoices -> auto-move, no confirmation".
/// Rules are OFF (require review) by default; only an explicit `autoApply = true`
/// lets the organizer skip the confirmation step for files matching it.
final class OrganizationRule: Codable, Identifiable {
    let id: UUID
    var name: String
    var matchCategory: String
    var matchSubcategory: String?
    var destinationSubpath: String // relative to the chosen root folder, e.g. "Finance/Invoices"
    var autoApply: Bool
    var autoRename: Bool
    var enabled: Bool
    var createdAt: Date

    init(name: String, matchCategory: String, matchSubcategory: String?, destinationSubpath: String, autoApply: Bool = false, autoRename: Bool = false) {
        self.id = UUID()
        self.name = name
        self.matchCategory = matchCategory
        self.matchSubcategory = matchSubcategory
        self.destinationSubpath = destinationSubpath
        self.autoApply = autoApply
        self.autoRename = autoRename
        self.enabled = true
        self.createdAt = Date()
    }
}
