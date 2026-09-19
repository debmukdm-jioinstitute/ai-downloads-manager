import Foundation

/// Local-first persistence: each collection is a JSON file under Application Support.
/// No cloud, no network — everything the app knows about your files lives on disk here.
/// This replaces SwiftData only because this build environment lacks the Xcode-only
/// SwiftData macro plugin; swapping in SwiftData/Core Data later is a drop-in change
/// behind the same interface (insert/save/query methods below).
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var fileRecords: [FileRecord] = []
    @Published private(set) var operations: [OperationRecord] = []
    @Published private(set) var activity: [ActivityEvent] = []
    @Published private(set) var rules: [OrganizationRule] = []
    @Published private(set) var expiryRecords: [ExpiryRecord] = []

    private let directory: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let baseSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appSupport = baseSupport.appendingPathComponent("Nest", isDirectory: true)

        // One-time migration from the app's pre-rename data folder, so
        // existing local libraries aren't silently orphaned by the rename.
        let legacySupport = baseSupport.appendingPathComponent("AIDownloadsManager", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appSupport.path),
           FileManager.default.fileExists(atPath: legacySupport.path) {
            try? FileManager.default.moveItem(at: legacySupport, to: appSupport)
        }

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.directory = appSupport

        fileRecords = load("files.json")
        operations = load("operations.json")
        activity = load("activity.json")
        rules = load("rules.json")
        expiryRecords = load("expiry.json")
    }

    // MARK: - Files

    func insertFile(_ record: FileRecord) {
        fileRecords.append(record)
        saveFiles()
    }

    func fileRecord(withPath path: String) -> FileRecord? {
        fileRecords.first { $0.currentPath == path }
    }

    /// One-time (self-healing, cheap to call repeatedly) cleanup for a bug
    /// where FSEvents' recursive subtree reporting let build/git internals
    /// (.build, .git, Sources/, ...) get ingested as if they were downloads
    /// whenever a project folder lived inside a watched folder. Removes
    /// anything that isn't a direct child of any currently-watched folder,
    /// plus any expiry records that pointed at it. Returns how many were
    /// removed.
    /// Generic self-heal hook for expiry records that a fixed bug now says
    /// should never have existed (e.g. a research report fabricated an
    /// "Insurance" expiry). Only ever removes what the caller's predicate
    /// selects — callers are expected to scope it to records the user never
    /// touched, the same discipline as pruneFileRecords.
    @discardableResult
    func removeExpiryRecords(where predicate: (ExpiryRecord) -> Bool) -> Int {
        let idsToRemove = Set(expiryRecords.filter(predicate).map(\.id))
        guard !idsToRemove.isEmpty else { return 0 }
        expiryRecords.removeAll { idsToRemove.contains($0.id) }
        saveExpiryRecords()
        return idsToRemove.count
    }

    @discardableResult
    func pruneFileRecords(notDirectChildrenOfAny folders: [URL]) -> Int {
        let roots = Set(folders.map { $0.standardizedFileURL.path })
        let idsToRemove = Set(fileRecords.filter {
            !roots.contains(URL(fileURLWithPath: $0.currentPath).deletingLastPathComponent().standardizedFileURL.path)
        }.map(\.id))
        guard !idsToRemove.isEmpty else { return 0 }
        fileRecords.removeAll { idsToRemove.contains($0.id) }
        expiryRecords.removeAll { idsToRemove.contains($0.documentID) }
        saveFiles()
        saveExpiryRecords()
        return idsToRemove.count
    }

    /// Removes a stale record (and anything keyed off its id) so a changed
    /// file at the same path gets one up-to-date record, not a second one.
    func removeFile(_ record: FileRecord) {
        fileRecords.removeAll { $0.id == record.id }
        saveFiles()
        removeExpiryRecords(forDocumentID: record.id)
    }

    func fileRecords(withHash hash: String) -> [FileRecord] {
        fileRecords.filter { $0.contentHash == hash }
    }

    func saveFiles() {
        persist(fileRecords, to: "files.json")
        objectWillChange.send()
    }

    // MARK: - Operations

    func insertOperation(_ op: OperationRecord) {
        operations.append(op)
        persist(operations, to: "operations.json")
    }

    // MARK: - Activity

    func insertActivity(_ event: ActivityEvent) {
        activity.insert(event, at: 0)
        if activity.count > 500 { activity.removeLast(activity.count - 500) }
        persist(activity, to: "activity.json")
    }

    // MARK: - Rules

    func insertRule(_ rule: OrganizationRule) {
        rules.append(rule)
        persist(rules, to: "rules.json")
    }

    // MARK: - Expiry Records

    func hasExpiryRecord(documentID: UUID, eventType: ExpiryEventType, date: Date) -> Bool {
        let calendar = Calendar.current
        return expiryRecords.contains {
            $0.documentID == documentID && $0.eventType == eventType && calendar.isDate($0.date, inSameDayAs: date)
        }
    }

    func insertExpiryRecord(_ record: ExpiryRecord) {
        expiryRecords.append(record)
        saveExpiryRecords()
    }

    func removeExpiryRecords(forDocumentID documentID: UUID) {
        expiryRecords.removeAll { $0.documentID == documentID }
        saveExpiryRecords()
    }

    func saveExpiryRecords() {
        persist(expiryRecords, to: "expiry.json")
        objectWillChange.send()
    }

    // MARK: - Disk I/O

    private func load<T: Codable>(_ filename: String) -> [T] {
        let url = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([T].self, from: data)) ?? []
    }

    private func persist<T: Codable>(_ items: [T], to filename: String) {
        let url = directory.appendingPathComponent(filename)
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
