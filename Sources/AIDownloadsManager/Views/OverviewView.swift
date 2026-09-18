import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFile: FileRecord?
    @State private var refreshToken = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Downloads Overview")
                    .font(.title2.bold())

                let stats = appState.dashboardStats()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    statCard(value: "\(stats.totalFiles)", label: "Files", icon: "doc.on.doc")
                    statCard(value: "\(stats.unorganized)", label: "Unorganized", icon: "questionmark.folder")
                    statCard(value: "\(stats.suggestedActions)", label: "Suggested Actions", icon: "sparkles")
                    statCard(value: formatBytes(stats.storageUsedBytes), label: "Storage Used", icon: "internaldrive")
                }

                HStack {
                    Text("Processed today: \(stats.filesProcessedToday)")
                    Text("·").foregroundStyle(.secondary)
                    Text("This week: \(stats.filesProcessedThisWeek)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let folder = appState.downloadsFolder {
                    HStack {
                        Image(systemName: appState.isMonitoring ? "dot.radiowaves.left.and.right" : "pause.circle")
                            .foregroundStyle(appState.isMonitoring ? .green : .secondary)
                        Text("Watching \(folder.path)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            .padding(24)
        }
        .navigationTitle("Overview")
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(value).font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct FileRow: View {
    let file: FileRecord

    var body: some View {
        HStack {
            Image(systemName: iconName(for: file.fileExtension))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename).lineLimit(1)
                Text("\(file.category)\(file.subcategory.map { " / \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let confidence = file.aiConfidence {
                Text("\(Int(confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
