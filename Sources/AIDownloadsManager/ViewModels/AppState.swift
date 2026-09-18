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

    let store: LibraryStore
    let ollamaSetup = OllamaSetupCoordinator()
    private var monitor: FolderMonitor?
    private var pipeline: FileIngestPipeline?
    private var cancellables: Set<AnyCancellable> = []

    init(store: LibraryStore) {
        self.store = store
        self.hasCompletedOnboarding = FolderAccessStore.hasSavedFolder
        self.downloadsFolder = FolderAccessStore.resolve()
        self.aiEnabled = UserDefaults.standard.bool(forKey: "aiEnabled")
        self.hasSeenAIConsent = UserDefaults.standard.bool(forKey: "hasSeenAIConsent")
        self.ollamaHost = UserDefaults.standard.string(forKey: "ollamaHost") ?? "http://localhost:11434"
        self.ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.2:1b"

        self.pipeline = FileIngestPipeline(
            store: store,
            aiServiceProvider: { [weak self] in self?.makeAIService() ?? NullAIService() },
            aiEnabledProvider: { [weak self] in self?.aiEnabled ?? false }
        )

        store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        ollamaSetup.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        ollamaSetup.$stage
            .sink { [weak self] stage in
                guard let self, stage == .ready else { return }
                self.aiEnabled = true
                self.hasSeenAIConsent = true
            }
            .store(in: &cancellables)

        if let folder = downloadsFolder {
            startMonitoring(folder: folder)
        }
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
        for path in paths {
            await pipeline.ingest(path: path)
        }
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
