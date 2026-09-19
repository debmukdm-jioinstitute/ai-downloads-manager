import SwiftUI
import AppKit

struct OverviewView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFile: FileRecord?
    @State private var refreshToken = UUID()
    @State private var selectedExpiryRecord: ExpiryRecord?
    @State private var searchQuery = ""
    @State private var searchResults: [(file: FileRecord, confidence: Int)] = []
    @State private var isSearching = false
    @State private var searchNotice: String?
    @State private var scannedCount = 0
    @State private var totalToScan = 0

    private var isSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Downloads Overview")
                    .font(.title2.bold())

                universalSearchBar

                if isSearchActive {
                    searchResultsSection
                } else {
                    dashboardContent
                }
            }
            .padding(24)
        }
        .navigationTitle("Overview")
        .sheet(item: $selectedExpiryRecord) { record in
            ExpiryDetailView(record: record)
        }
    }

    /// Everything the Overview page shows when no search is active — the
    /// stat cards, watched folders, attention list, and its own local
    /// Needs Review preview. Pulled out so the search bar above can swap it
    /// out for `searchResultsSection` without duplicating this whole block.
    private var dashboardContent: some View {
        Group {

                let stats = appState.dashboardStats()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    statCard(value: "\(stats.totalFiles)", label: "Files", icon: "doc.on.doc") {
                        appState.selectedSidebarSection = .allFiles
                    }
                    statCard(value: "\(stats.unorganized)", label: "Unorganized", icon: "questionmark.folder") {
                        appState.selectedSidebarSection = .categories
                    }
                    statCard(value: "\(stats.suggestedActions)", label: "Suggested Actions", icon: "sparkles") {
                        appState.selectedSidebarSection = .categories
                    }
                    // Storage Used has nowhere meaningful to navigate to, so it
                    // stays a plain info card rather than faking clickability.
                    statCard(value: formatBytes(stats.storageUsedBytes), label: "Storage Used", icon: "internaldrive", action: nil)
                }

                HStack {
                    Text("Processed today: \(stats.filesProcessedToday)")
                    Text("·").foregroundStyle(.secondary)
                    Text("This week: \(stats.filesProcessedThisWeek)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                ForEach(appState.watchedFolders, id: \.self) { folder in
                    WatchedFolderRow(folder: folder, isMonitoring: appState.isMonitoring)
                }

                let attentionItems = appState.expiryRecords().filter {
                    $0.userStatus == .active && !$0.needsReview &&
                    [.expired, .critical].contains($0.urgency(windows: appState.expiryUrgencyWindows) ?? .future)
                }
                if !attentionItems.isEmpty {
                    Divider().padding(.vertical, 4)
                    Text("Today's Attention").font(.headline)
                    ForEach(attentionItems.prefix(5)) { record in
                        AttentionRow(record: record) { selectedExpiryRecord = record }
                    }
                }

                Divider().padding(.vertical, 4)

                Text("Needs Review")
                    .font(.headline)
                let needsReview = appState.allFiles().filter { $0.processingStatus == .needsReview }
                if needsReview.isEmpty {
                    Text("Nothing needs review right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(needsReview.prefix(10)) { file in
                        FileRow(file: file)
                            .onTapGesture { selectedFile = file }
                    }
                }
        }
    }

    private var universalSearchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sparkle.magnifyingglass")
                TextField("Ask in plain language — try \"inflation\", \"tax invoices\"...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit(runSearch)
                if isSearching {
                    ProgressView().controlSize(.small)
                }
                if isSearchActive {
                    Button {
                        searchQuery = ""
                        searchResults = []
                        searchNotice = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))

            if isSearching && totalToScan > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: Double(scannedCount), total: Double(totalToScan))
                    Text("Scanned \(scannedCount) of \(totalToScan) files…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let searchNotice {
                Text(searchNotice).font(.caption).foregroundStyle(.orange)
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchResults = []
                searchNotice = nil
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Results for \u{201C}\(searchQuery)\u{201D} (\(searchResults.count))")
                .font(.headline)
            if searchResults.isEmpty {
                Text(isSearching ? "Searching…" : "No files matched. Try a different word or phrase.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(searchResults, id: \.file.id) { result in
                    FileRow(file: result.file, matchConfidence: result.confidence)
                        .onTapGesture { selectedFile = result.file }
                }
            }
        }
    }

    private func runSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        searchNotice = nil
        scannedCount = 0
        totalToScan = appState.allFiles().count
        Task {
            var filters: AISearchFilters?
            if appState.aiEnabled {
                do {
                    filters = try await appState.makeAIService().interpretSearchQuery(trimmed)
                } catch {
                    await MainActor.run {
                        searchNotice = "AI couldn't interpret the query; showing local text-match results instead."
                    }
                }
            }
            let scored = await SearchService.searchScored(query: trimmed, in: appState.allFiles(), aiFilters: filters) { done, total in
                scannedCount = done
                totalToScan = total
            }
            let maxScore = scored.map(\.score).max() ?? 0
            let withConfidence = scored.map { entry in
                (file: entry.file, confidence: maxScore > 0 ? Int((Double(entry.score) / Double(maxScore) * 100).rounded()) : 0)
            }
            await MainActor.run {
                searchResults = withConfidence
                isSearching = false
            }
        }
    }

    private func statCard(value: String, label: String, icon: String, action: (() -> Void)?) -> some View {
        StatCard(value: value, label: label, icon: icon, action: action)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let action: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary)
                Spacer()
                if action != nil {
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Text(value).font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .quaternary.opacity((isHovering && action != nil) ? 0.6 : 0.4),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .contentShape(Rectangle())
        .onTapGesture { action?() }
        .onHover { hovering in
            guard action != nil else { return }
            isHovering = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

private struct AttentionRow: View {
    let record: ExpiryRecord
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            let days = record.daysRemaining()
            Text(days < 0
                 ? "\(record.title) — expired \(-days) day\(-days == 1 ? "" : "s") ago"
                 : "\(record.title) — \(record.eventType.displayName.lowercased()) in \(days) day\(days == 1 ? "" : "s")")
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(.quaternary.opacity(isHovering ? 0.35 : 0), in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hovering in
            isHovering = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

private struct WatchedFolderRow: View {
    let folder: URL
    let isMonitoring: Bool
    @State private var isHovering = false

    var body: some View {
        HStack {
            Image(systemName: isMonitoring ? "dot.radiowaves.left.and.right" : "pause.circle")
                .foregroundStyle(isMonitoring ? .green : .secondary)
            Text("Watching \(folder.path)")
                .font(.caption)
                .foregroundStyle(isHovering ? .primary : .secondary)
            Image(systemName: "arrow.up.forward.square")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
        .onHover { hovering in
            isHovering = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct FileRow: View {
    let file: FileRecord
    /// When set (e.g. from a search result's relevance score), shown instead
    /// of the file's own classification confidence — the two numbers answer
    /// different questions and showing both would just be confusing.
    var matchConfidence: Int? = nil
    @State private var isHovering = false

    var body: some View {
        HStack {
            Image(systemName: iconName(for: file.fileExtension))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename).lineLimit(1)
                Text("\(file.category)\(file.subcategory.map { " / \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(file.currentPath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let matchConfidence {
                Text("\(matchConfidence)% match")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let confidence = file.aiConfidence {
                Text("\(Int(confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(.quaternary.opacity(isHovering ? 0.35 : 0), in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func iconName(for ext: String) -> String {
        switch ext {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "heic", "webp": return "photo"
        case "zip": return "archivebox"
        case "xls", "xlsx", "csv": return "tablecells"
        case "ppt", "pptx": return "rectangle.on.rectangle"
        default: return "doc"
        }
    }
}
