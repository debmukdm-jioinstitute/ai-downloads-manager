import SwiftUI
import QuickLookThumbnailing
import AppKit

struct FilePreviewPane: View {
    @EnvironmentObject var appState: AppState
    let file: FileRecord
    var onClose: (() -> Void)? = nil
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
    @State private var showingDeleteConfirm = false
    @State private var showingTweakAppliedName = false
    @State private var appliedName = ""
    @State private var tweakedName = ""

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
                    if let onClose {
                        Spacer()
                        Button { onClose() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Close")
                    }
                }

                if let suggestion = FilenameSuggestionEngine.suggest(for: file), suggestion != file.filename {
                    suggestedNameRow(suggestion)
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
                    Button("Delete", role: .destructive) { showingDeleteConfirm = true }
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
        .sheet(isPresented: $showingTweakAppliedName) {
            tweakAppliedNameSheet
        }
        .confirmationDialog(
            "Delete \(file.filename)?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                do {
                    try appState.organizer()?.delete(file)
                    onClose?()
                } catch FileOrganizerError.sourceMissing {
                    handleMissingSource()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This moves the file at \(file.currentPath) to the Trash. You can restore it from there if needed.")
        }
        // Keyed on the file's id: a plain `.task { }` only ever runs once per
        // view *slot*, not per `file` value — this pane stays in the same
        // slot in the detail column across selections, so without the id it
        // kept showing the first file's thumbnail forever while every other
        // field correctly updated to match the new selection.
        .task(id: file.id) {
            thumbnail = nil
            guard FileManager.default.fileExists(atPath: file.currentPath) else {
                handleMissingSource()
                return
            }
            await loadThumbnail()
        }
    }

    /// The file this pane is showing turned out not to exist at its recorded
    /// path (deleted or moved outside Nest) — drop it from the library and
    /// close the pane rather than leave stale details on screen.
    private func handleMissingSource() {
        appState.removeMissingFile(file)
        onClose?()
    }

    /// The recommended filename (see FilenameSuggestionEngine), shown right
    /// under the current one — the "dropdown" is a single-option Picker
    /// rather than a plain label since that's the requested affordance, even
    /// though only one name is ever proposed per file today. Bound to a
    /// getter/setter reading the suggestion directly instead of a separate
    /// @State, so there's no per-file-switch sync to forget (the same class
    /// of stale-state bug just fixed for the thumbnail above).
    private func suggestedNameRow(_ suggestion: String) -> some View {
        HStack {
            Image(systemName: "sparkles").foregroundStyle(.secondary)
            Text("AI suggests:").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: Binding(get: { suggestion }, set: { _ in })) {
                Text(suggestion).tag(suggestion)
            }
            .labelsHidden()
            .frame(maxWidth: 240)
            Spacer()
            Button("Apply Changes") { applySuggestedName(suggestion) }
        }
    }

    private func applySuggestedName(_ suggestion: String) {
        do {
            try appState.organizer()?.rename(file, to: suggestion)
        } catch FileOrganizerError.sourceMissing {
            handleMissingSource()
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        // rename() sanitizes and de-duplicates the requested name, so what
        // actually landed on disk (file.filename, now updated) may differ
        // slightly from the raw suggestion — that's what gets offered for
        // one more tweak, not the pre-sanitized string.
        appliedName = file.filename
        tweakedName = appliedName
        showingTweakAppliedName = true
    }

    private var tweakAppliedNameSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name Applied").bold()
            Text("Renamed to \u{201C}\(appliedName)\u{201D}. Want to tweak the wording or extension before confirming?")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Filename", text: $tweakedName)
            HStack {
                Spacer()
                Button("Confirm") {
                    if tweakedName != appliedName {
                        do {
                            try appState.organizer()?.rename(file, to: tweakedName)
                        } catch FileOrganizerError.sourceMissing {
                            handleMissingSource()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    showingTweakAppliedName = false
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 380)
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
                    } catch FileOrganizerError.sourceMissing {
                        handleMissingSource()
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
                    } catch FileOrganizerError.sourceMissing {
                        handleMissingSource()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    showingMove = false
                }.buttonStyle(.borderedProminent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Or move it to a specific folder — anywhere on this Mac, including iCloud Drive.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Choose Folder…") { moveToCustomFolder() }
            }
        }
        .padding(20).frame(width: 360)
    }

    private func moveToCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a destination folder for \(file.filename)"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try appState.organizer()?.moveToFolder(file, destination: destination)
        } catch FileOrganizerError.sourceMissing {
            handleMissingSource()
        } catch {
            errorMessage = error.localizedDescription
        }
        showingMove = false
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
