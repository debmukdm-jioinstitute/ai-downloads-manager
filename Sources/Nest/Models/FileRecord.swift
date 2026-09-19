import Foundation

enum ProcessingStatus: String, Codable {
    case pending
    case processing
    case processed
    case needsReview
    case failed
}

final class FileRecord: Codable, Identifiable, Equatable {
    let id: UUID
    var filename: String
    var originalPath: String
    var currentPath: String
    var fileExtension: String
    var utType: String
    var fileSize: Int64
    var creationDate: Date
    var modificationDate: Date
    var dateDownloaded: Date
    var contentHash: String?
    var mimeType: String?

    var category: String
    var subcategory: String?
    var tags: [String]

    var extractedText: String?
    var ocrText: String?
    var aiSummary: String?
    var aiConfidence: Double?

    var detectedEntities: [String]
    var detectedVendor: String?
    var detectedDocumentType: String?
    var detectedDate: Date?
    var detectedDueDate: Date?
    var detectedAmount: Double?
    var detectedCurrency: String?
    /// A document-specific identifier the AI found — invoice number,
    /// passport number, PNR, etc. Generic on purpose: which kind of
    /// identifier it is is already implied by `category`/`subcategory`.
    var detectedIdentifierNumber: String?
    /// "low"/"medium"/"high" — the AI's judgment of how sensitive this
    /// document's contents are (a passport or bank statement vs. a meeting
    /// agenda). Not currently enforced anywhere; a hook for future features
    /// (e.g. never reading a high-sensitivity document aloud) rather than a
    /// promise that low-sensitivity handling exists today.
    var sensitivity: String?
    /// AI's suggested rename (e.g. "Amazon Invoice - Sep 2026.pdf"), applied
    /// only when auto-organizing a high-confidence file — never silently
    /// applied at classification time, since a rename is more disruptive
    /// than a category tag if the AI got it wrong.
    var suggestedFilename: String?

    var duplicateGroupID: UUID?

    var isProcessed: Bool
    var processingStatus: ProcessingStatus
    var processingError: String?

    var userApprovedClassification: Bool
    var userModifiedCategory: Bool

    var classificationReason: String?

    init(
        filename: String,
        originalPath: String,
        currentPath: String,
        fileExtension: String,
        utType: String,
        fileSize: Int64,
        creationDate: Date,
        modificationDate: Date,
        dateDownloaded: Date = Date()
    ) {
        self.id = UUID()
        self.filename = filename
        self.originalPath = originalPath
        self.currentPath = currentPath
        self.fileExtension = fileExtension
        self.utType = utType
        self.fileSize = fileSize
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.dateDownloaded = dateDownloaded
        self.category = "Other"
        self.subcategory = "Uncategorized"
        self.tags = []
        self.detectedEntities = []
        self.isProcessed = false
        self.processingStatus = .pending
        self.userApprovedClassification = false
        self.userModifiedCategory = false
    }

    static func == (lhs: FileRecord, rhs: FileRecord) -> Bool { lhs.id == rhs.id }
}
