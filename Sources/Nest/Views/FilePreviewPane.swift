import SwiftUI
import QuickLookThumbnailing
import AppKit

struct FilePreviewPane: View {
    @EnvironmentObject var appState: AppState
    let file: FileRecord
    @State private var thumbnail: NSImage?
    @State private var showingRename = false
    @State private var newName = ""
    @State private var showingMove = false
    @State private var moveCategory = "Other"
    @State private var moveSubcategory: String?
    @State private var showingAskAI = false
    @State private var question = ""
    @State private var aiAnswer: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    if let thumbnail {
                        Image(nsImage: thumbnail).resizable().frame(width: 64, height: 64).cornerRadius(8)
                    } else {
                        Image(systemName: "doc").font(.system(size: 40)).frame(width: 64, height: 64)
                    }
                    VStack(alignment: .leading) {
                        Text(file.filename).font(.headline)
                        Text(file.currentPath).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }

                infoRow("Size", ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                infoRow("Downloaded", file.dateDownloaded.formatted(date: .abbreviated, time: .shortened))
                infoRow("Category", "\(file.category)\(file.subcategory.map { " / \($0)" } ?? "")")
                if !file.tags.isEmpty { infoRow("Tags", file.tags.joined(separator: ", ")) }
                if let confidence = file.aiConfidence { infoRow("Confidence", "\(Int(confidence * 100))%") }
                if let reason = file.classificationReason {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Why this category").font(.caption).foregroundStyle(.secondary)
                        Text(reason).font(.callout)
                    }
                }
                if let summary = file.aiSummary {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Summary").font(.caption).foregroundStyle(.secondary)
                        Text(summary).font(.callout)
                    }
                }
                if let vendor = file.detectedVendor { infoRow("Vendor", vendor) }
                if let amount = file.detectedAmount { infoRow("Amount", "\(file.detectedCurrency ?? "")\(amount)") }
                if let groupID = file.duplicateGroupID {
                    infoRow("Duplicate group", groupID.uuidString.prefix(8).description)
                }
                if let error = file.processingError {
                    Text("Processing note: \(error)").font(.caption).foregroundStyle(.orange)
                }

                Divider()

                HStack {
                    Button("Open") { NSWorkspace.shared.open(URL(fileURLWithPath: file.currentPath)) }
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.currentPath)]) }
                    Button("Quick Look") { QuickLookCoordinator.shared.toggle(url: URL(fileURLWithPath: file.currentPath)) }
                        .help("Or just press Space")
                }
                HStack {
                    Button("Rename") {
                        newName = file.filename
                        showingRename = true
                    }
                    Button("Move") {
                        moveCategory = file.category
                        moveSubcategory = file.subcategory
                        showingMove = true
                    }
                    Button("Ask AI") { showingAskAI = true }
                        .disabled(!appState.aiEnabled)
                }

                if let aiAnswer {
                    Text(aiAnswer).font(.callout).padding(.top, 4)
                }
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .navigationTitle(file.filename)
        .sheet(isPresented: $showingRename) {
            renameSheet
        }
        .sheet(isPresented: $showingMove) {
            moveSheet
        }
        .sheet(isPresented: $showingAskAI) {
            askAISheet
        }
        .task { await loadThumbnail() }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(value).font(.callout)
        }
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename File").bold()
            TextField("New filename", text: $newName)
            HStack {
                Spacer()
                Button("Cancel") { showingRename = false }
                Button("Rename") {
                    do {
                        try appState.organizer()?.rename(file, to: newName)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    showingRename = false
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 360)
    }

    private var moveSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move File").bold()
            Picker("Category", selection: $moveCategory) {
                ForEach(CategoryTaxonomy.allCategories, id: \.self) { Text($0).tag($0) }
            }
            .onChange(of: moveCategory) { _, newCategory in
                // A subcategory from the previous category (e.g. "Invoices"
                // under "Finance") isn't valid under the newly-picked one —
                // reset it rather than silently submitting an invalid pair.
                if let sub = moveSubcategory, !CategoryTaxonomy.subcategories(for: newCategory).contains(sub) {
                    moveSubcategory = nil
                }
            }
            Picker("Subcategory", selection: Binding(get: { moveSubcategory ?? "" }, set: { moveSubcategory = $0.isEmpty ? nil : $0 })) {
                Text("None").tag("")
                ForEach(CategoryTaxonomy.subcategories(for: moveCategory), id: \.self) { Text($0).tag($0) }
            }
            HStack {
                Spacer()
                Button("Cancel") { showingMove = false }
                Button("Move") {
                    do {
                        try appState.organizer()?.moveToCategory(file, category: moveCategory, subcategory: moveSubcategory)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    showingMove = false
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 360)
    }

    private var askAISheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask AI about this file").bold()
            TextField("Your question", text: $question)
            HStack {
                Spacer()
                Button("Cancel") { showingAskAI = false }
                Button("Ask") {
                    Task {
                        let context = file.aiSummary ?? file.extractedText ?? file.ocrText ?? "No extracted content available."
                        do {
                            aiAnswer = try await appState.makeAIService().answer(question: question, context: context)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        showingAskAI = false
                    }
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 400)
    }

    private func loadThumbnail() async {
        let url = URL(fileURLWithPath: file.currentPath)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 64, height: 64), scale: scale, representationTypes: .thumbnail)
        if let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            thumbnail = representation.nsImage
        }
    }
}
