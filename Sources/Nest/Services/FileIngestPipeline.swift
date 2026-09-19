import Foundation
import UniformTypeIdentifiers

/// Orchestrates everything that happens to one newly-detected file:
/// metadata -> hash -> duplicate check -> text/OCR extraction -> classification -> persist.
@MainActor
final class FileIngestPipeline {
    private let store: LibraryStore
    private var aiServiceProvider: () -> AIService
    private var aiEnabledProvider: () -> Bool
    private var rootFoldersProvider: () -> [URL]

    init(store: LibraryStore, aiServiceProvider: @escaping () -> AIService, aiEnabledProvider: @escaping () -> Bool, rootFoldersProvider: @escaping () -> [URL]) {
        self.store = store
        self.aiServiceProvider = aiServiceProvider
        self.aiEnabledProvider = aiEnabledProvider
        self.rootFoldersProvider = rootFoldersProvider
    }

    /// Skips files that are unreadable, already indexed at the same path+hash,
    /// unsupported system files, or not a *direct* child of one of the
    /// watched folders. That last check is the authoritative guard against
    /// ever ingesting nested project internals (.build, .git, node_modules,
    /// ...) — FSEvents reports file changes anywhere in the watched subtree,
    /// and a watched folder is meant to be flat, so anything nested is never
    /// a real download regardless of which code path called this.
    /// Returns the created (or already up-to-date) record, or nil if the file was skipped.
    @discardableResult
    func ingest(path: String) async -> FileRecord? {
        let fm = FileManager.default
        guard fm.isReadableFile(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        guard !name.hasPrefix("."), !name.isEmpty else { return nil }
        let roots = rootFoldersProvider()
        if !roots.isEmpty {
            let parent = url.deletingLastPathComponent().standardizedFileURL.path
            guard roots.contains(where: { $0.standardizedFileURL.path == parent }) else { return nil }
        }

        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64,
              let creation = attrs[.creationDate] as? Date,
              let modification = attrs[.modificationDate] as? Date else { return nil }

        // A file evicted to iCloud ("Optimize Mac Storage") has no local
        // bytes yet — reading it (hashing, PDF/OCR extraction) silently
        // blocks the calling thread until it downloads, which can hang for
        // minutes or forever if offline. Kick off the download and skip for
        // now; FSEvents (or the next rescan) picks it up once it lands.
        if let cloudValues = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
           cloudValues.isUbiquitousItem == true,
           cloudValues.ubiquitousItemDownloadingStatus != .current {
            try? fm.startDownloadingUbiquitousItem(at: url)
            return nil
        }

        // Avoid reprocessing a path we already have an up-to-date record for.
        // If a record exists but the file has actually changed (re-exported,
        // overwritten in place), replace it rather than inserting a second,
        // independent record for the same path.
        if let existing = store.fileRecord(withPath: path) {
            if existing.modificationDate == modification, existing.fileSize == size {
                return nil
            }
            store.removeFile(existing)
        }

        let ext = url.pathExtension.lowercased()
        let utType = UTType(filenameExtension: ext)?.identifier ?? "public.data"
        let mimeType = UTType(filenameExtension: ext)?.preferredMIMEType

        let record = FileRecord(
            filename: name,
            originalPath: path,
            currentPath: path,
            fileExtension: ext,
            utType: utType,
            fileSize: size,
            creationDate: creation,
            modificationDate: modification
        )
        record.mimeType = mimeType
        record.processingStatus = .processing
        store.insertFile(record)
        store.insertActivity(ActivityEvent(kind: .detected, message: "New file detected", filename: name))

        switch await Self.extractContents(url: url, ext: ext, utType: utType) {
        case .timedOut:
            record.processingStatus = .needsReview
            record.processingError = "Timed out reading this file's contents (took longer than \(Int(Self.perFileTimeoutSeconds))s) — it may be a cloud-only, corrupted, or unusually large file."
            record.isProcessed = true
            store.insertActivity(ActivityEvent(kind: .classified, message: "Timed out reading file; needs review", filename: name))
            store.saveFiles()
            return record
        case .success(let hash, let text, let ocr):
            record.contentHash = hash
            record.extractedText = text
            record.ocrText = ocr
        }

        if let hash = record.contentHash {
            let others = store.fileRecords(withHash: hash).filter { $0.id != record.id }
            if let firstOther = others.first {
                let groupID = firstOther.duplicateGroupID ?? UUID()
                firstOther.duplicateGroupID = groupID
                record.duplicateGroupID = groupID
                store.insertActivity(ActivityEvent(kind: .duplicate, message: "Duplicate of \(firstOther.filename)", filename: name))
            }
        }

        let local = ClassificationEngine.classify(filename: name, fileExtension: ext, extractedText: record.extractedText, ocrText: record.ocrText)
        applyLocal(local, to: record)

        // Only escalate to the local LLM when local classification is genuinely
        // unsure — a real bulk rescan with AI enabled was measured at ~90s per
        // file (llama3.2:1b generating a full classification per document,
        // strictly sequentially), which made a ~300-file backlog look hung
        // when it was really just going to take hours. Most files are already
        // confidently classified by fast, free heuristics; AI only earns its
        // cost on the ones those heuristics couldn't place.
        if aiEnabledProvider(), local.confidence < CategoryTaxonomy.reviewConfidenceThreshold,
           let textForAI = record.extractedText ?? record.ocrText, !textForAI.isEmpty {
            do {
                let ai = try await Self.classifyWithTimeout(aiService: aiServiceProvider(), filename: name, extractedText: textForAI)
                applyAI(ai, to: record)
            } catch {
                // Local classification already applied; just log why AI didn't improve on it.
                record.processingError = error.localizedDescription
            }
        }

        record.isProcessed = true
        let effectiveConfidence = record.aiConfidence ?? local.confidence
        record.processingStatus = effectiveConfidence < CategoryTaxonomy.reviewConfidenceThreshold ? .needsReview : .processed

        store.insertActivity(ActivityEvent(kind: .classified, message: "Classified as \(record.category)\(record.subcategory.map { "/\($0)" } ?? "")", filename: name))
        store.saveFiles()
        return record
    }

    nonisolated private static let perFileTimeoutSeconds: UInt64 = 20
    nonisolated private static let textExtractableExtensions: Set<String> = [
        "pdf", "txt", "csv", "rtf", "rtfd", "doc", "docx", "odt", "wordml", "xlsx", "pptx"
    ]

    private enum ContentResult {
        case success(hash: String?, text: String?, ocr: String?)
        case timedOut
    }

    /// Hashing, PDF text extraction, and OCR are synchronous, non-cancellable
    /// blocking calls. Racing them against a timeout is the only way to stop
    /// one bad file (corrupt PDF, giant image, stalled network mount) from
    /// hanging the whole sequential ingest queue forever — a real hang hit
    /// while recovering the library after a prior incident. The losing task
    /// (usually the real work, on a timeout) keeps running in the background
    /// to completion since it can't be preempted, but its result is discarded.
    nonisolated private static func extractContents(url: URL, ext: String, utType: String) async -> ContentResult {
        await withTaskGroup(of: ContentResult.self) { group in
            group.addTask {
                let hash = HashService.sha256(ofFileAt: url)
                var text: String?
                if Self.textExtractableExtensions.contains(ext) {
                    text = TextExtractionService.extractText(fileURL: url, utType: utType, fileExtension: ext)
                }
                var ocr: String?
                if OCRService.imageExtensions.contains(ext) {
                    ocr = OCRService.recognizeText(imageURL: url)
                } else if ext == "pdf" && (text?.isEmpty ?? true) {
                    // A scanned/photographed PDF has no text layer at all —
                    // PDFKit returns nil for every page — so it would
                    // otherwise never be searchable or classifiable by
                    // content, only by filename. Rasterize and OCR it the
                    // same way a plain image file already is.
                    ocr = OCRService.recognizeText(scannedPDFURL: url)
                }
                return .success(hash: hash, text: text, ocr: ocr)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: perFileTimeoutSeconds * 1_000_000_000)
                return .timedOut
            }
            let result = await group.next() ?? .timedOut
            group.cancelAll()
            return result
        }
    }

    nonisolated private static let aiTimeoutSeconds: UInt64 = 45

    private struct AITimeoutError: LocalizedError {
        var errorDescription: String? { "AI classification timed out after \(FileIngestPipeline.aiTimeoutSeconds)s" }
    }

    /// A hung or unreachable Ollama server would otherwise block this file
    /// (and every file after it, since ingestion is sequential) forever —
    /// same class of bug as the hash/extract/OCR hang above, just further
    /// down the pipeline.
    nonisolated private static func classifyWithTimeout(aiService: AIService, filename: String, extractedText: String) async throws -> AIClassificationResult {
        try await withThrowingTaskGroup(of: AIClassificationResult.self) { group in
            group.addTask {
                try await aiService.classifyFile(filename: filename, extractedText: extractedText)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: aiTimeoutSeconds * 1_000_000_000)
                throw AITimeoutError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func applyLocal(_ local: LocalClassification, to record: FileRecord) {
        record.category = local.category
        record.subcategory = local.subcategory
        record.tags = local.tags
        record.detectedVendor = local.vendor
        record.detectedDocumentType = local.documentType
        record.detectedAmount = local.amount
        record.detectedCurrency = local.currency
        record.aiConfidence = local.confidence
        record.classificationReason = local.reason
    }

    private func applyAI(_ ai: AIClassificationResult, to record: FileRecord) {
        record.category = ai.category
        record.subcategory = ai.subcategory
        record.tags = ai.tags
        record.aiSummary = ai.summary
        record.aiConfidence = ai.confidence
        record.detectedVendor = ai.vendor ?? record.detectedVendor
        record.detectedDocumentType = ai.documentType ?? record.detectedDocumentType
        record.detectedAmount = ai.amount ?? record.detectedAmount
        record.detectedCurrency = ai.currency ?? record.detectedCurrency
        record.classificationReason = ai.reason ?? record.classificationReason
        record.detectedIdentifierNumber = ai.identifierNumber ?? record.detectedIdentifierNumber
        record.sensitivity = ai.sensitivity ?? record.sensitivity
        record.suggestedFilename = ai.suggestedFilename ?? record.suggestedFilename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let dateString = ai.documentDate {
            record.detectedDate = dateFormatter.date(from: dateString)
        }
        if let dueDateString = ai.dueDate {
            record.detectedDueDate = dateFormatter.date(from: dueDateString)
        }
        var entities: [String] = []
        if let person = ai.person { entities.append(person) }
        if let org = ai.organization { entities.append(org) }
        record.detectedEntities = entities
    }
}
