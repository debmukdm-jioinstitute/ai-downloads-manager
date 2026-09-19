import Foundation

enum ActivityKind: String, Codable {
    case detected
    case processed
    case classified
    case duplicate
    case moved
    case renamed
    case deleted
    case undone
    case error
    case aiDisabled
    case aiEnabled
}

final class ActivityEvent: Codable, Identifiable {
    let id: UUID
    var kind: ActivityKind
    var message: String
    var filename: String?
    var timestamp: Date

    init(kind: ActivityKind, message: String, filename: String? = nil) {
        self.id = UUID()
        self.kind = kind
        self.message = message
        self.filename = filename
        self.timestamp = Date()
    }
}
