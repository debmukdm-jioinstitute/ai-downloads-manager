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
    var detectedAmount: Double?
    var detectedCurrency: String?

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
