import Foundation

enum FileOrganizerError: Error, LocalizedError {
    case sourceMissing
    case destinationCreateFailed
    case moveFailed(String)
    case invalidCategory(String, String?)

    var errorDescription: String? {
        switch self {
        case .sourceMissing: return "The source file no longer exists."
        case .destinationCreateFailed: return "Could not create the destination folder."
        case .moveFailed(let reason): return "Move failed: \(reason)"
        case .invalidCategory(let category, let subcategory):
            return "\"\(subcategory ?? "—")\" isn't a valid subcategory of \"\(category)\"."
        }
    }
}

/// Every mutation goes through here so it's always recorded and always undoable.
/// Nothing in this type ever deletes a file.
@MainActor
final class FileOrganizerService {
    private let store: LibraryStore

    init(store: LibraryStore) {
        self.store = store
    }

    /// Moves a file into `category/subcategory` beneath the watched folder
    /// it was originally found in. With multiple watched folders, each file
    /// stays organized within its own — `originalPath` never changes once a
    /// file is ingested (unlike `currentPath`, which moves), so its parent
    /// directory is always that file's true watched root regardless of how
    /// many times it's since been moved or renamed.
    /// Never overwrites: if a name collision exists, a " 2", " 3"... suffix is used.
    @discardableResult
    func moveToCategory(_ record: FileRecord, category: String, subcategory: String?) throws -> OperationRecord {
        guard CategoryTaxonomy.isValid(category: category, subcategory: subcategory) else {
            throw FileOrganizerError.invalidCategory(category, subcategory)
        }
        let rootFolder = URL(fileURLWithPath: record.originalPath).deletingLastPathComponent()
        var destDir = rootFolder.appendingPathComponent(category, isDirectory: true)
        if let subcategory { destDir.appendPathComponent(subcategory, isDirectory: true) }

        let op = try performMove(record, to: destDir, reason: "Moved to \(category)\(subcategory.map { "/\($0)" } ?? "")")
        record.category = category
        record.subcategory = subcategory
        store.saveFiles()
        return op
    }

    /// Moves a file to an arbitrary destination the user picked directly —
    /// e.g. a folder in iCloud Drive — rather than a category/subcategory
    /// beneath its watched root. Category/subcategory are left as-is; only
    /// the file's physical location changes. The destination doesn't need
    /// to be inside any watched folder.
    @discardableResult
    func moveToFolder(_ record: FileRecord, destination: URL) throws -> OperationRecord {
        try performMove(record, to: destination, reason: "Moved to \(destination.path)")
    }

    /// Deletes the file at its current on-disk location by moving it to the
    /// Trash (recoverable there, same as deleting in Finder) and drops its
    /// entry — and any expiry records tied to it — from the library index.
    @discardableResult
    func delete(_ record: FileRecord) throws -> OperationRecord {
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: record.currentPath)
        guard fm.fileExists(atPath: sourceURL.path) else { throw FileOrganizerError.sourceMissing }

        var trashedURL: NSURL?
        do {
            try fm.trashItem(at: sourceURL, resultingItemURL: &trashedURL)
        } catch {
            throw FileOrganizerError.moveFailed(error.localizedDescription)
        }

        let op = OperationRecord(kind: .delete, fileRecordID: record.id, fromPath: sourceURL.path, toPath: (trashedURL as URL?)?.path ?? "", reason: "Deleted (moved to Trash)")
        store.insertOperation(op)
        store.insertActivity(ActivityEvent(kind: .deleted, message: "Deleted (moved to Trash)", filename: record.filename))
        store.removeFile(record)
        return op
    }

    private func performMove(_ record: FileRecord, to destDir: URL, reason: String) throws -> OperationRecord {
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: record.currentPath)
        guard fm.fileExists(atPath: sourceURL.path) else { throw FileOrganizerError.sourceMissing }

        do {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            throw FileOrganizerError.destinationCreateFailed
        }

        let uniqueName = FilenameSanitizer.uniqueFilename(record.filename, in: destDir)
        let destURL = destDir.appendingPathComponent(uniqueName)

        do {
            try fm.moveItem(at: sourceURL, to: destURL)
        } catch {
            throw FileOrganizerError.moveFailed(error.localizedDescription)
        }

        let op = OperationRecord(kind: .move, fileRecordID: record.id, fromPath: sourceURL.path, toPath: destURL.path, reason: reason)
        store.insertOperation(op)

        record.currentPath = destURL.path
        record.filename = uniqueName
        record.userApprovedClassification = true

        store.insertActivity(ActivityEvent(kind: .moved, message: reason, filename: uniqueName))
        store.saveFiles()
        return op
    }

    @discardableResult
    func rename(_ record: FileRecord, to newName: String) throws -> OperationRecord {
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: record.currentPath)
        guard fm.fileExists(atPath: sourceURL.path) else { throw FileOrganizerError.sourceMissing }

        let directory = sourceURL.deletingLastPathComponent()
        let sanitized = FilenameSanitizer.sanitize(newName)
        let uniqueName = FilenameSanitizer.uniqueFilename(sanitized, in: directory)
        let destURL = directory.appendingPathComponent(uniqueName)

        do {
            try fm.moveItem(at: sourceURL, to: destURL)
        } catch {
            throw FileOrganizerError.moveFailed(error.localizedDescription)
        }

        let op = OperationRecord(kind: .rename, fileRecordID: record.id, fromPath: sourceURL.path, toPath: destURL.path, reason: "Renamed")
        store.insertOperation(op)

        record.currentPath = destURL.path
        record.filename = uniqueName

        store.insertActivity(ActivityEvent(kind: .renamed, message: "Renamed to \(uniqueName)", filename: uniqueName))
        store.saveFiles()
        return op
    }

    /// Restores a file to its path before the given operation.
    func undo(_ op: OperationRecord, record: FileRecord) throws {
        let fm = FileManager.default
        let currentURL = URL(fileURLWithPath: op.toPath)
        let originalURL = URL(fileURLWithPath: op.fromPath)
        guard fm.fileExists(atPath: currentURL.path) else { throw FileOrganizerError.sourceMissing }

        try fm.createDirectory(at: originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: originalURL.path) {
            throw FileOrganizerError.moveFailed("A file already exists at the original location.")
        }
        try fm.moveItem(at: currentURL, to: originalURL)

        op.undone = true
        record.currentPath = originalURL.path
        record.filename = originalURL.lastPathComponent
        store.insertActivity(ActivityEvent(kind: .undone, message: "Undid move/rename", filename: record.filename))
        store.saveFiles()
    }
}
