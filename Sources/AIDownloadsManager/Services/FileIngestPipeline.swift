import Foundation
import UniformTypeIdentifiers

/// Orchestrates everything that happens to one newly-detected file:
/// metadata -> hash -> duplicate check -> text/OCR extraction -> classification -> persist.
@MainActor
final class FileIngestPipeline {
    private let store: LibraryStore
    private var aiServiceProvider: () -> AIService
    private var aiEnabledProvider: () -> Bool

    init(store: LibraryStore, aiServiceProvider: @escaping () -> AIService, aiEnabledProvider: @escaping () -> Bool) {
        self.store = store
        self.aiServiceProvider = aiServiceProvider
        self.aiEnabledProvider = aiEnabledProvider
    }

    /// Skips files that are unreadable, already indexed at the same path+hash, or unsupported system files.
    func ingest(path: String) async {
        let fm = FileManager.default
        guard fm.isReadableFile(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        guard !name.hasPrefix("."), !name.isEmpty else { return }

        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64,
              let creation = attrs[.creationDate] as? Date,
              let modification = attrs[.modificationDate] as? Date else { return }

        // Avoid reprocessing a path we already have an up-to-date record for.
        if let existing = store.fileRecord(withPath: path),
           existing.modificationDate == modification, existing.fileSize == size {
            return
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

        record.contentHash = HashService.sha256(ofFileAt: url)

        if let hash = record.contentHash {
            let others = store.fileRecords(withHash: hash).filter { $0.id != record.id }
            if let firstOther = others.first {
                let groupID = firstOther.duplicateGroupID ?? UUID()
                firstOther.duplicateGroupID = groupID
                record.duplicateGroupID = groupID
                store.insertActivity(ActivityEvent(kind: .duplicate, message: "Duplicate of \(firstOther.filename)", filename: name))
            }
        }

        if ext == "pdf" || ext == "txt" || ext == "csv" || ext == "rtf" {
            record.extractedText = TextExtractionService.extractText(fileURL: url, utType: utType, fileExtension: ext)
        }
        if OCRService.imageExtensions.contains(ext) {
            record.ocrText = OCRService.recognizeText(imageURL: url)
        }

        let local = ClassificationEngine.classify(filename: name, fileExtension: ext, extractedText: record.extractedText, ocrText: record.ocrText)
        applyLocal(local, to: record)

        if aiEnabledProvider(), let textForAI = record.extractedText ?? record.ocrText, !textForAI.isEmpty {
            do {
                let ai = try await aiServiceProvider().classifyFile(filename: name, extractedText: textForAI)
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
        if let dateString = ai.documentDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            record.detectedDate = formatter.date(from: dateString)
        }
        var entities: [String] = []
        if let person = ai.person { entities.append(person) }
        if let org = ai.organization { entities.append(org) }
        record.detectedEntities = entities
    }
}
