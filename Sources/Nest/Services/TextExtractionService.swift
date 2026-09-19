import Foundation
import PDFKit

/// Everything here is offline, on-device, and uses only what macOS already
/// ships: PDFKit for PDF, and for Office-family formats the system's own
/// `textutil` (Word-family: doc/docx/odt/rtf/rtfd/wordml) and `unzip`
/// (xlsx/pptx are ZIP archives of XML — Info-ZIP's `unzip` is part of the
/// base OS, no third-party dependency needed). Legacy binary `.xls`/`.ppt`
/// (pre-2007 Office) have no equivalent built-in reader and aren't covered.
enum TextExtractionService {
    private static let maxExtractedChars = 20_000
    /// Vision OCR and per-slide unzip+parse are real work per unit — cap how
    /// many slides a single pptx contributes, the same reasoning as the PDF
    /// OCR page cap: what a deck is about is almost always on its early slides.
    private static let maxSlidesForText = 40

    static func extractText(fileURL: URL, utType: String, fileExtension: String) -> String? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "pdf":
            return extractPDFText(fileURL)
        case "txt", "csv":
            return extractPlainText(fileURL)
        case "rtf", "rtfd", "doc", "docx", "odt", "wordml":
            return extractViaTextutil(fileURL)
        case "xlsx":
            return extractXLSXText(fileURL)
        case "pptx":
            return extractPPTXText(fileURL)
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

    /// doc/docx/odt/rtf/rtfd/wordml all go through the same system converter
    /// rather than each getting bespoke parsing — `textutil` already reads
    /// every one of them and reliably strips markup down to plain text,
    /// which a raw-bytes read (the old approach for `.rtf`) never did.
    private static func extractViaTextutil(_ url: URL) -> String? {
        guard let output = runProcess("/usr/bin/textutil", ["-convert", "txt", "-stdout", url.path]),
              let text = String(data: output, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxExtractedChars))
    }

    /// .xlsx is a ZIP of XML; nearly all real cell text (not formulas/numbers)
    /// lives in one shared table rather than repeated per-sheet, so reading
    /// just that one entry covers the practical case cheaply.
    private static func extractXLSXText(_ url: URL) -> String? {
        guard let data = runProcess("/usr/bin/unzip", ["-p", url.path, "xl/sharedStrings.xml"]) else { return nil }
        let text = collectElementText(from: data, elementLocalName: "t")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxExtractedChars))
    }

    /// .pptx is also a ZIP of XML, one file per slide (`ppt/slides/slideN.xml`)
    /// with text runs in `<a:t>` elements.
    private static func extractPPTXText(_ url: URL) -> String? {
        guard let listing = runProcess("/usr/bin/unzip", ["-Z1", url.path]),
              let listingText = String(data: listing, encoding: .utf8) else { return nil }
        let slideEntries = listingText
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") }
            .sorted { slideNumber(in: $0) < slideNumber(in: $1) }
            .prefix(maxSlidesForText)

        var combined = ""
        for entry in slideEntries {
            guard let data = runProcess("/usr/bin/unzip", ["-p", url.path, entry]) else { continue }
            combined += collectElementText(from: data, elementLocalName: "a:t") + "\n"
            if combined.count > maxExtractedChars { break }
        }
        let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxExtractedChars))
    }

    private static func slideNumber(in path: String) -> Int {
        let name = (path as NSString).lastPathComponent
        return Int(name.filter(\.isNumber)) ?? 0
    }

    private static func collectElementText(from xmlData: Data, elementLocalName: String) -> String {
        let collector = XMLTextCollector(targetElement: elementLocalName)
        let parser = XMLParser(data: xmlData)
        parser.delegate = collector
        _ = parser.parse()
        return collector.collected
    }

    private static func runProcess(_ executablePath: String, _ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else { return nil }
        return data
    }
}

/// Collects character content found inside every occurrence of one element
/// (matched by its unprefixed/local name, e.g. "t" or "a:t" as XMLParser
/// reports it without namespace processing enabled), regardless of nested
/// formatting runs inside it.
private final class XMLTextCollector: NSObject, XMLParserDelegate {
    private let targetElement: String
    private var depth = 0
    private(set) var collected = ""

    init(targetElement: String) {
        self.targetElement = targetElement
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == targetElement { depth += 1 }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if depth > 0 { collected += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == targetElement {
            depth -= 1
            collected += "\n"
        }
    }
}
