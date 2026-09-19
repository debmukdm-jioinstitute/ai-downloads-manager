import Foundation

enum OperationKind: String, Codable {
    case move
    case rename
    case delete
}

/// Records every file-system mutation the app performs so it can be shown in
/// Activity and undone. Nothing here ever deletes a file except an explicit,
/// user-confirmed delete — and even that moves the file to the Trash rather
/// than removing it outright, so it stays recoverable.
final class OperationRecord: Codable, Identifiable {
    let id: UUID
    var kind: OperationKind
    var fileRecordID: UUID
    var fromPath: String
    var toPath: String
    var timestamp: Date
    var undone: Bool
    var reason: String?

    init(kind: OperationKind, fileRecordID: UUID, fromPath: String, toPath: String, reason: String? = nil) {
        self.id = UUID()
        self.kind = kind
        self.fileRecordID = fileRecordID
        self.fromPath = fromPath
        self.toPath = toPath
        self.timestamp = Date()
        self.undone = false
        self.reason = reason
    }
}
