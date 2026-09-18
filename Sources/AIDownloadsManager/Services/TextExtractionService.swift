import Foundation
import PDFKit

enum TextExtractionService {
    private static let maxExtractedChars = 20_000

    static func extractText(fileURL: URL, utType: String, fileExtension: String) -> String? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "pdf":
            return extractPDFText(fileURL)
        case "txt", "csv", "rtf":
            return extractPlainText(fileURL)
        default:
            return nil
        }
    }

    private static func extractPDFText(_ url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        var text = ""
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            if let pageText = page.string {
                text += pageText + "\n"
            }
            if text.count > maxExtractedChars { break }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxExtractedChars))
    }

    private static func extractPlainText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        guard let string else { return nil }
        return String(string.prefix(maxExtractedChars))
    }
}
