import Foundation

/// The "Document Events" engine referenced in the product spec: date
/// detection -> context analysis -> optional AI refinement -> confidence ->
/// ExpiryRecord -> store. Deliberately generic (expiry/deadline/renewal/event
/// all flow through here), not an "expiry-only" feature.
@MainActor
final class ExpiryDetectionPipeline {
    private let store: LibraryStore
    private var aiServiceProvider: () -> AIService
    private var aiEnabledProvider: () -> Bool

    init(store: LibraryStore, aiServiceProvider: @escaping () -> AIService, aiEnabledProvider: @escaping () -> Bool) {
        self.store = store
        self.aiServiceProvider = aiServiceProvider
        self.aiEnabledProvider = aiEnabledProvider
    }

    /// Runs detection for one file and stores any new (non-duplicate) records.
    /// Returns the number of new records created.
    @discardableResult
    func detectAndStore(for file: FileRecord) async -> Int {
        let text = file.extractedText ?? ""
        let ocr = file.ocrText
        guard !text.isEmpty || !(ocr?.isEmpty ?? true) else { return 0 }

        // Cheap pre-filter: skip the AI round-trip entirely if there isn't
        // even a date-shaped substring anywhere in the text.
        let combinedForScan = text.isEmpty ? (ocr ?? "") : text
        guard !DateDetectionEngine.detectDates(in: combinedForScan).isEmpty
                || DateDetectionEngine.detectValidityDuration(in: combinedForScan) != nil else { return 0 }

        var drafts = ExpiryContextClassifier.classify(filename: file.filename, text: text, ocrText: ocr, fromOCR: text.isEmpty)

        if aiEnabledProvider() {
            let aiText = text.isEmpty ? (ocr ?? "") : text
            if let aiDrafts = try? await aiServiceProvider().extractDocumentEvents(filename: file.filename, extractedText: aiText),
               !aiDrafts.importantDates.isEmpty {
                drafts = convert(aiDrafts, filename: file.filename)
            }
        }

        var created = 0
        let fromOCR = text.isEmpty
        for draft in drafts {
            guard !store.hasExpiryRecord(documentID: file.id, eventType: draft.eventType, date: draft.date) else { continue }
            let record = ExpiryRecord(
                documentID: file.id,
                documentFilename: file.filename,
                eventType: draft.eventType,
                title: draft.title,
                category: draft.category,
                date: draft.date,
                sourceText: draft.sourceText,
                fromOCR: fromOCR,
                confidence: draft.confidence,
                isExplicit: draft.isExplicit,
                isDerived: draft.isDerived,
                aiContext: draft.aiContext,
                recurrence: draft.recurrence
            )
            if draft.eventType == .expiry || draft.eventType == .renewal {
                record.reminderDate = Calendar.current.date(byAdding: .day, value: -30, to: draft.date)
            }
            store.insertExpiryRecord(record)
            created += 1
        }
        return created
    }

    private func convert(_ result: AIDocumentEventsResult, filename: String) -> [ExpiryRecordDraft] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return result.importantDates.compactMap { event -> ExpiryRecordDraft? in
            guard let eventType = ExpiryEventType(rawValue: event.type.uppercased()),
                  let date = formatter.date(from: event.date) else { return nil }
            let category = ExpiryContextClassifier.categoryGuess(forDocumentType: result.documentType, filename: filename)
            return ExpiryRecordDraft(
                eventType: eventType,
                title: category != "Other" ? category : (result.documentType ?? eventType.displayName),
                category: category,
                date: date,
                sourceText: event.sourceText,
                confidence: event.confidence,
                isExplicit: event.explicit,
                isDerived: !event.explicit,
                aiContext: nil,
                recurrence: nil
            )
        }
    }
}
