import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    /// Every folder Nest watches. Was a single `downloadsFolder: URL?` —
    /// widened to a list so the app isn't restricted to one folder (still
    /// scoped to folders the user explicitly picks, not the whole disk).
    @Published var watchedFolders: [URL] = []
    @Published var aiEnabled: Bool {
        didSet { UserDefaults.standard.set(aiEnabled, forKey: "aiEnabled") }
    }
    @Published var hasSeenAIConsent: Bool {
        didSet { UserDefaults.standard.set(hasSeenAIConsent, forKey: "hasSeenAIConsent") }
    }
    @Published var ollamaHost: String {
        didSet { UserDefaults.standard.set(ollamaHost, forKey: "ollamaHost") }
    }
    @Published var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel") }
    }
    @Published var isMonitoring = false
    @Published var lastError: String?

    @Published var expiryUrgencyWindows: ExpiryUrgencyWindows {
        didSet { expiryUrgencyWindows.saveToDefaults() }
    }
    @Published var notifyOffsetDays: Set<Int> {
        didSet {
            UserDefaults.standard.set(Array(notifyOffsetDays), forKey: "notifyOffsetDays")
            Task { await rescheduleExpiryNotifications() }
        }
    }
    @Published var notifyOnExpiry: Bool {
        didSet {
            UserDefaults.standard.set(notifyOnExpiry, forKey: "notifyOnExpiry")
            Task { await rescheduleExpiryNotifications() }
        }
    }
    @Published var notifyOnlyHighConfidence: Bool {
        didSet {
            UserDefaults.standard.set(notifyOnlyHighConfidence, forKey: "notifyOnlyHighConfidence")
            Task { await rescheduleExpiryNotifications() }
        }
    }
    @Published var notificationsAuthorized = false

    @Published var selectedSidebarSection: SidebarSection = .overview
    /// Set by voice input (hotkey or "Hey Nest"); SearchView picks this up,
    /// runs it, and clears it — this is how a voice command reaches the tab
    /// that actually executes it.
    @Published var pendingVoiceQuery: String?
    @Published var voiceCommandsEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceCommandsEnabled, forKey: "voiceCommandsEnabled") }
    }
    @Published var wakeWordEnabled: Bool {
        didSet { UserDefaults.standard.set(wakeWordEnabled, forKey: "wakeWordEnabled") }
    }
    @Published var speakResultsAloud: Bool {
        didSet { UserDefaults.standard.set(speakResultsAloud, forKey: "speakResultsAloud") }
    }
    /// AVSpeechSynthesisVoice identifier. Empty means "system default voice".
    @Published var speechVoiceIdentifier: String {
        didSet { UserDefaults.standard.set(speechVoiceIdentifier, forKey: "speechVoiceIdentifier") }
    }
    /// Opt-in, off by default: Nest's baseline promise is "files are only
    /// moved with your review or explicit rule" — this deliberately breaks
    /// that promise for the two highest confidence tiers only, and only when
    /// the user has explicitly turned it on.
    @Published var autoOrganizeConfidentFiles: Bool {
        didSet { UserDefaults.standard.set(autoOrganizeConfidentFiles, forKey: "autoOrganizeConfidentFiles") }
    }

    let store: LibraryStore
    let ollamaSetup = OllamaSetupCoordinator()
    private var monitors: [String: FolderMonitor] = [:] // keyed by standardized folder path
    private var pipeline: FileIngestPipeline?
    private var expiryPipeline: ExpiryDetectionPipeline?
    private var cancellables: Set<AnyCancellable> = []

    init(store: LibraryStore) {
        self.store = store
        self.hasCompletedOnboarding = FolderAccessStore.hasSavedFolders
        self.watchedFolders = FolderAccessStore.resolveAll()
        self.aiEnabled = UserDefaults.standard.bool(forKey: "aiEnabled")
        self.hasSeenAIConsent = UserDefaults.standard.bool(forKey: "hasSeenAIConsent")
        self.ollamaHost = UserDefaults.standard.string(forKey: "ollamaHost") ?? "http://localhost:11434"
        // Qwen2.5 1.5B (Apache-2.0): measured on this machine (M1, 8GB) at
        // roughly 2x llama3.2:1b's tokens/sec even though it has more
        // parameters — Qwen2.5's architecture is just more efficient here.
        // Tried qwen2.5:0.5b first since it's smaller still, but at that size
        // it degenerated into a repeating loop and produced invalid JSON on
        // real documents, which costs a full retry round-trip (or fails
        // outright) — a bad trade for a small extra speedup. 1.5B was
        // reliable across every test run.
        self.ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "qwen2.5:1.5b"
        self.expiryUrgencyWindows = ExpiryUrgencyWindows.loadFromDefaults()
        if let savedOffsets = UserDefaults.standard.array(forKey: "notifyOffsetDays") as? [Int] {
            self.notifyOffsetDays = Set(savedOffsets)
        } else {
            self.notifyOffsetDays = [30, 7]
        }
        self.notifyOnExpiry = UserDefaults.standard.object(forKey: "notifyOnExpiry") as? Bool ?? true
        self.notifyOnlyHighConfidence = UserDefaults.standard.object(forKey: "notifyOnlyHighConfidence") as? Bool ?? true
        self.voiceCommandsEnabled = UserDefaults.standard.bool(forKey: "voiceCommandsEnabled")
        self.wakeWordEnabled = UserDefaults.standard.bool(forKey: "wakeWordEnabled")
        self.speakResultsAloud = UserDefaults.standard.object(forKey: "speakResultsAloud") as? Bool ?? true
        self.speechVoiceIdentifier = UserDefaults.standard.string(forKey: "speechVoiceIdentifier") ?? ""
        self.autoOrganizeConfidentFiles = UserDefaults.standard.bool(forKey: "autoOrganizeConfidentFiles")

        self.pipeline = FileIngestPipeline(
            store: store,
            aiServiceProvider: { [weak self] in self?.makeAIService() ?? NullAIService() },
            aiEnabledProvider: { [weak self] in self?.aiEnabled ?? false },
            rootFoldersProvider: { [weak self] in self?.watchedFolders ?? [] }
        )
        self.expiryPipeline = ExpiryDetectionPipeline(
            store: store,
            aiServiceProvider: { [weak self] in self?.makeAIService() ?? NullAIService() },
            aiEnabledProvider: { [weak self] in self?.aiEnabled ?? false }
        )

        store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        ollamaSetup.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        // Deliberately no "stage == .ready -> aiEnabled = true" sink here: that
        // would enable AI the instant setup succeeds even if Ollama happened to
        // already be installed/running before the user answered the consent
        // screen (autoStart can reach .ready almost immediately in that case),
        // silently enabling AI out from under a user who was about to tap Skip.
        // Every consent surface (AIConsentSheet's onReady, onboarding's Skip)
        // sets aiEnabled explicitly instead, so "enabled" only ever follows a
        // real user action.

        for folder in watchedFolders {
            startMonitoring(folder: folder)
        }
        reclassifyLocallyClassifiedFiles()
        removeStaleResearchReportExpiryRecords()
        Task { await upgradeStaleExpiryDetections() }
    }

    /// Explicit, user-initiated cleanup for records that don't belong under
    /// the currently-watched folder (leftover pollution from before
    /// FolderMonitor/FileIngestPipeline rejected nested paths, or from having
    /// pointed Nest at a different folder previously). Deliberately NOT run
    /// automatically at launch: doing that once silently deleted 285 good
    /// records because the watched-folder *setting itself* had been changed
    /// (to iCloud Drive) — an automatic prune trusts that setting completely,
    /// and a wrong or changed setting makes it a silent, un-confirmed mass
    /// deletion. It only ever removes index/metadata, never the real files.
    @discardableResult
    func cleanUpLibrary() -> Int {
        guard !watchedFolders.isEmpty else { return 0 }
        return store.pruneFileRecords(notDirectChildrenOfAny: watchedFolders)
    }

    /// Drops a single record the user just discovered points at a file that's
    /// actually gone (moved or deleted outside Nest). Deliberately not a
    /// background sweep — only ever called from a moment where the user is
    /// looking straight at that one file, for the same reason `cleanUpLibrary`
    /// above isn't automatic: a wrong existence check (e.g. an un-downloaded
    /// iCloud placeholder) must never silently mass-delete records.
    func removeMissingFile(_ record: FileRecord) {
        store.removeFile(record)
        store.insertActivity(ActivityEvent(kind: .deleted, message: "Removed from library — file no longer found on disk", filename: record.filename))
    }

    /// Self-heal for a real classification bug: naive substring keyword
    /// matching classified anything mentioning "billion"/"billing" as an
    /// invoice (the word "bill" matched inside them). Fixing the matcher
    /// only prevents *future* misclassification, so this re-runs local
    /// classification (cheap, offline, idempotent) once at launch for every
    /// record that was never AI-classified (no aiSummary — the exact
    /// signature of a local-only classification) and that the user hasn't
    /// already approved or corrected, so already-fixed and user-confirmed
    /// files are never silently overwritten.
    private func reclassifyLocallyClassifiedFiles() {
        var changed = false
        for record in store.fileRecords where record.aiSummary == nil && !record.userApprovedClassification {
            let local = ClassificationEngine.classify(
                filename: record.filename,
                fileExtension: record.fileExtension,
                extractedText: record.extractedText,
                ocrText: record.ocrText
            )
            guard local.category != record.category || local.subcategory != record.subcategory else { continue }
            record.category = local.category
            record.subcategory = local.subcategory
            record.tags = local.tags
            record.detectedVendor = local.vendor
            record.detectedDocumentType = local.documentType
            record.detectedAmount = local.amount
            record.detectedCurrency = local.currency
            record.aiConfidence = local.confidence
            record.classificationReason = local.reason
            record.processingStatus = local.confidence < CategoryTaxonomy.reviewConfidenceThreshold ? .needsReview : .processed
            changed = true
        }
        if changed { store.saveFiles() }
    }

    /// Self-heal for a real bug: equity/analyst research reports were getting
    /// fabricated personal expiry dates (a stock research report tagged
    /// "Insurance expiring 2020" purely from the word "coverage" in "analyst
    /// coverage"). Recomputing ExpiryContextClassifier's exclusion is cheap
    /// and deterministic, so this only strips records that could never
    /// legitimately exist under the current rules — and only ones the user
    /// never touched (still active, never added to Calendar), the same
    /// "never silently override a real user action" discipline as the file
    /// reclassification self-heal above.
    /// Self-heal, one-time only: real airline e-tickets almost never use
    /// words like "departure"/"boarding" near a date (they say "Terminal 2",
    /// "PNR", "Travel time"), so before those phrases were added to
    /// ExpiryContextClassifier's keyword list, virtually every flight date
    /// fell through to the generic 0.35 "no keyword nearby" fallback —
    /// exactly why every record looked identically unconfident. Fixing the
    /// keyword list only helps *future* scans unless already-indexed files
    /// get re-run too, so this clears out every expiry record the user never
    /// touched (still .active, never added to Calendar) and re-detects them
    /// with the current rules. Gated to run once, not on every launch — if
    /// AI is enabled, re-detection makes a real Ollama call per affected
    /// file, and this isn't meant to become a recurring cost.
    private func upgradeStaleExpiryDetections() async {
        let migrationKey = "expiryKeywordSelfHealV1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        UserDefaults.standard.set(true, forKey: migrationKey)
        guard let expiryPipeline else { return }

        let untouchedIDs = Set(store.expiryRecords.filter { $0.userStatus == .active && $0.calendarEventIdentifier == nil }.map(\.id))
        guard !untouchedIDs.isEmpty else { return }
        let affectedDocumentIDs = Set(store.expiryRecords.filter { untouchedIDs.contains($0.id) }.map(\.documentID))
        store.removeExpiryRecords { untouchedIDs.contains($0.id) }

        for documentID in affectedDocumentIDs {
            guard let file = store.fileRecords.first(where: { $0.id == documentID }) else { continue }
            await expiryPipeline.detectAndStore(for: file)
        }
        await rescheduleExpiryNotifications()
    }

    private func removeStaleResearchReportExpiryRecords() {
        store.removeExpiryRecords { record in
            guard record.userStatus == .active, record.calendarEventIdentifier == nil else { return false }
            guard let file = store.fileRecords.first(where: { $0.id == record.documentID }) else { return false }
            let combined = ((file.extractedText ?? "") + " " + (file.ocrText ?? "")).lowercased()
            return TextMatching.containsAnyWord(combined, ExpiryContextClassifier.researchReportMarkers)
        }
    }

    func makeAIService() -> AIService {
        guard aiEnabled, !ollamaModel.isEmpty else { return NullAIService() }
        return OllamaAIService(host: ollamaHost, model: ollamaModel)
    }

    /// Adds a folder to the watch list — a no-op if it's already watched —
    /// starts monitoring it, and scans its existing contents. This is the
    /// one path both onboarding's first folder and Settings' "Add Folder"
    /// go through, so a user is never limited to a single folder.
    func addWatchedFolder(_ url: URL) {
        let standardized = url.standardizedFileURL.path
        guard !watchedFolders.contains(where: { $0.standardizedFileURL.path == standardized }) else { return }
        FolderAccessStore.addFolder(url)
        watchedFolders.append(url)
        startMonitoring(folder: url)
        scanExistingFiles(in: url)
    }

    /// Stops watching a folder. Deliberately does NOT remove its already-
    /// indexed files — that stays an explicit, confirmed action via "Clean
    /// Up Library" rather than an automatic side effect of unwatching, for
    /// the same reason the automatic prune was removed earlier: an automatic
    /// mass-delete tied to a setting change is exactly what caused a real
    /// data-loss incident.
    func removeWatchedFolder(_ url: URL) {
        let standardized = url.standardizedFileURL.path
        monitors[standardized]?.stop()
        monitors[standardized] = nil
        watchedFolders.removeAll { $0.standardizedFileURL.path == standardized }
        FolderAccessStore.removeFolder(url)
        isMonitoring = !monitors.isEmpty
    }

    /// Used by onboarding: adds the folder without finishing onboarding yet,
    /// so the AI setup step can run before landing on the dashboard.
    func selectFolder(_ url: URL) {
        addWatchedFolder(url)
    }

    func chooseFolder(_ url: URL) {
        selectFolder(url)
        hasCompletedOnboarding = true
    }

    func startMonitoring(folder: URL) {
        let standardized = folder.standardizedFileURL.path
        monitors[standardized]?.stop()
        let monitor = FolderMonitor(folderURL: folder) { [weak self] paths in
            guard let self else { return }
            Task { await self.handleChangedPaths(paths) }
        }
        monitors[standardized] = monitor
        monitor.start()
        isMonitoring = true
    }

    func scanExistingFiles(in folder: URL) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        let paths = entries.filter { !$0.hasDirectoryPath }.map { $0.path }
        Task { await handleChangedPaths(paths) }
    }

    private func handleChangedPaths(_ paths: [String]) async {
        guard let pipeline else { return }
        var createdAnyExpiryRecord = false
        for path in paths {
            guard let record = await pipeline.ingest(path: path) else { continue }
            if let expiryPipeline {
                let created = await expiryPipeline.detectAndStore(for: record)
                if created > 0 { createdAnyExpiryRecord = true }
            }
            if autoOrganizeConfidentFiles {
                autoOrganizeIfConfident(record)
            }
        }
        if createdAnyExpiryRecord {
            await rescheduleExpiryNotifications()
        }
    }

    /// Confidence-tiered automation, opt-in via `autoOrganizeConfidentFiles`.
    /// Only the two highest tiers ever move a file — .confirm (70-84%) and
    /// below never do, matching the "ask before committing" principle the
    /// review threshold itself is built on. The 85-94% tier still moves the
    /// file (per the tier's own definition) but logs a distinctly-worded
    /// activity entry asking for a glance, rather than silently succeeding
    /// exactly like the 95%+ tier does.
    private func autoOrganizeIfConfident(_ record: FileRecord) {
        guard record.processingStatus != .needsReview,
              let confidence = record.aiConfidence,
              let organizer = organizer() else { return }
        let tier = CategoryTaxonomy.confidenceAction(for: confidence)
        guard tier == .autoOrganize || tier == .autoOrganizeNotify else { return }
        guard (try? organizer.moveToCategory(record, category: record.category, subcategory: record.subcategory)) != nil else { return }

        if let suggested = record.suggestedFilename, !suggested.isEmpty {
            try? organizer.rename(record, to: suggested)
        }

        if tier == .autoOrganizeNotify {
            store.insertActivity(ActivityEvent(kind: .classified, message: "Auto-organized (\(Int(confidence * 100))% confident) — worth a quick check", filename: record.filename))
        }
    }

    // MARK: - Expiry / Document Events

    func expiryRecords() -> [ExpiryRecord] {
        store.expiryRecords.sorted { $0.date < $1.date }
    }

    struct ExpiryScanSummary {
        var filesScanned: Int
        var supportedDocuments: Int
        var documentsWithDates: Int
        var recordsCreated: Int
    }

    /// "Scan for important dates" — runs expiry detection over the *existing*
    /// library, not just newly-downloaded files, so the feature is useful
    /// retroactively (spec section 18).
    func scanForImportantDates() async -> ExpiryScanSummary {
        guard let expiryPipeline else {
            return ExpiryScanSummary(filesScanned: 0, supportedDocuments: 0, documentsWithDates: 0, recordsCreated: 0)
        }
        let files = allFiles()
        let withText = files.filter { !($0.extractedText ?? "").isEmpty || !($0.ocrText ?? "").isEmpty }
        var withDates = 0
        var created = 0
        for file in withText {
            let count = await expiryPipeline.detectAndStore(for: file)
            if count > 0 { withDates += 1 }
            created += count
        }
        if created > 0 {
            await rescheduleExpiryNotifications()
        }
        return ExpiryScanSummary(
            filesScanned: files.count,
            supportedDocuments: withText.count,
            documentsWithDates: withDates,
            recordsCreated: created
        )
    }

    func setExpiryUserStatus(_ record: ExpiryRecord, status: ExpiryUserStatus) {
        record.userStatus = status
        record.updatedAt = Date()
        store.saveExpiryRecords()
        Task { await rescheduleExpiryNotifications() }
    }

    /// "Confirm" on a low-confidence detection was a no-op: it called
    /// setExpiryUserStatus(record, status: .active) on a record that was
    /// already .active (that's the only way it lands in Needs Review in the
    /// first place — see ExpiryRecord.needsReview), so nothing visibly
    /// changed. What the user is actually doing is vouching for a detection
    /// the app itself was unsure about, so that should read as full
    /// confidence — the same way FileRecord.userApprovedClassification
    /// treats a user's own correction as ground truth.
    func confirmExpiryRecord(_ record: ExpiryRecord) {
        record.confidence = 1.0
        record.userStatus = .active
        record.updatedAt = Date()
        store.saveExpiryRecords()
        Task { await rescheduleExpiryNotifications() }

        // Confirming the detection is also the user vouching for the whole
        // record, so file the underlying document away too — using the
        // FILE's own category/subcategory (already computed by
        // ClassificationEngine/AI), not the expiry engine's own category
        // label ("Insurance", "Travel", ...), which is a separate free-text
        // taxonomy (ExpiryCategoryTaxonomy) that doesn't correspond to real
        // folder categories at all — "Insurance" isn't even a valid
        // CategoryTaxonomy entry, so moving by it would just fail.
        if let file = store.fileRecords.first(where: { $0.id == record.documentID }),
           let organizer = organizer() {
            try? organizer.moveToCategory(file, category: file.category, subcategory: file.subcategory)
        }
    }

    func updateExpiryDate(_ record: ExpiryRecord, date: Date) {
        record.date = date
        record.updatedAt = Date()
        store.saveExpiryRecords()
        Task { await rescheduleExpiryNotifications() }
    }

    func requestNotificationAuthorization() async {
        notificationsAuthorized = await ExpiryNotificationService.requestAuthorization()
        await rescheduleExpiryNotifications()
    }

    func rescheduleExpiryNotifications() async {
        await ExpiryNotificationService.reschedule(
            records: store.expiryRecords,
            offsetDays: notifyOffsetDays,
            notifyOnExpiry: notifyOnExpiry,
            onlyHighConfidence: notifyOnlyHighConfidence
        )
    }

    /// Routes a voice-recognized phrase (from the ⌘⌥ hotkey or "Hey Nest")
    /// into the Search tab, which performs the actual search — this stays the
    /// single place that runs a query, so a voice command doesn't trigger a
    /// second, redundant AI interpretation call on top of what Search does.
    func runVoiceCommand(_ transcript: String) {
        selectedSidebarSection = .search
        pendingVoiceQuery = transcript
    }

    func organizer() -> FileOrganizerService? {
        guard !watchedFolders.isEmpty else { return nil }
        return FileOrganizerService(store: store)
    }

    // MARK: - Dashboard queries

    func allFiles() -> [FileRecord] {
        store.fileRecords.sorted { $0.dateDownloaded > $1.dateDownloaded }
    }

    func recentActivity(limit: Int = 50) -> [ActivityEvent] {
        Array(store.activity.prefix(limit))
    }

    func rules() -> [OrganizationRule] {
        store.rules
    }

    struct DashboardStats {
        var filesProcessedToday: Int
        var filesProcessedThisWeek: Int
        var unorganized: Int
        var suggestedActions: Int
        var storageUsedBytes: Int64
        var totalFiles: Int
    }

    func dashboardStats() -> DashboardStats {
        let files = allFiles()
        let calendar = Calendar.current
        let now = Date()
        let todayCount = files.filter { calendar.isDate($0.dateDownloaded, inSameDayAs: now) }.count
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let weekCount = files.filter { $0.dateDownloaded >= weekStart }.count
        let unorganized = files.filter { $0.category == "Other" || $0.processingStatus == .needsReview }.count
        let totalSize = files.reduce(Int64(0)) { $0 + $1.fileSize }
        return DashboardStats(
            filesProcessedToday: todayCount,
            filesProcessedThisWeek: weekCount,
            unorganized: unorganized,
            suggestedActions: unorganized,
            storageUsedBytes: totalSize,
            totalFiles: files.count
        )
    }
}
