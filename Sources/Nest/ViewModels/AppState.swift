import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var downloadsFolder: URL?
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

    let store: LibraryStore
    let ollamaSetup = OllamaSetupCoordinator()
    private var monitor: FolderMonitor?
    private var pipeline: FileIngestPipeline?
    private var expiryPipeline: ExpiryDetectionPipeline?
    private var cancellables: Set<AnyCancellable> = []

    init(store: LibraryStore) {
        self.store = store
        self.hasCompletedOnboarding = FolderAccessStore.hasSavedFolder
        self.downloadsFolder = FolderAccessStore.resolve()
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

        self.pipeline = FileIngestPipeline(
            store: store,
            aiServiceProvider: { [weak self] in self?.makeAIService() ?? NullAIService() },
            aiEnabledProvider: { [weak self] in self?.aiEnabled ?? false },
            rootFolderProvider: { [weak self] in self?.downloadsFolder }
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

        if let folder = downloadsFolder {
            startMonitoring(folder: folder)
        }
        reclassifyLocallyClassifiedFiles()
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
        guard let folder = downloadsFolder else { return 0 }
        return store.pruneFileRecords(notDirectChildrenOf: folder)
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

    func makeAIService() -> AIService {
        guard aiEnabled, !ollamaModel.isEmpty else { return NullAIService() }
        return OllamaAIService(host: ollamaHost, model: ollamaModel)
    }

    /// Used by onboarding: picks the folder without finishing onboarding yet,
    /// so the AI setup step can run before landing on the dashboard.
    func selectFolder(_ url: URL) {
        FolderAccessStore.save(url: url)
        downloadsFolder = url
        startMonitoring(folder: url)
        scanExistingFiles(in: url)
    }

    func chooseFolder(_ url: URL) {
        selectFolder(url)
        hasCompletedOnboarding = true
    }

    func startMonitoring(folder: URL) {
        monitor?.stop()
        monitor = FolderMonitor(folderURL: folder) { [weak self] paths in
            guard let self else { return }
            Task { await self.handleChangedPaths(paths) }
        }
        monitor?.start()
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
        }
        if createdAnyExpiryRecord {
            await rescheduleExpiryNotifications()
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
        guard let folder = downloadsFolder else { return nil }
        return FileOrganizerService(store: store, rootFolder: folder)
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
