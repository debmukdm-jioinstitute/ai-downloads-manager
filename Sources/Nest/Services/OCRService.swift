import Foundation
import Vision
import AppKit
import PDFKit

enum OCRService {
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp", "gif"]

    /// A scanned/photographed PDF has no text layer — PDFKit's `page.string`
    /// returns nil for every page — so it's otherwise invisible to search
    /// and classification alike. Capped at the first few pages: full-accuracy
    /// Vision OCR is expensive per page, and what a scanned document is
    /// almost always shows on its opening pages anyway.
    static let maxScannedPDFPages = 5

    static func recognizeText(imageURL: URL) -> String? {
        guard let nsImage = NSImage(contentsOf: imageURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return recognizeText(cgImage: cgImage)
    }

    static func recognizeText(scannedPDFURL url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        var combined = ""
        let pageCount = min(document.pageCount, maxScannedPDFPages)
        for index in 0..<pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { continue }
            guard let cgImage = rasterize(page: page, bounds: bounds),
                  let pageText = recognizeText(cgImage: cgImage) else { continue }
            combined += pageText + "\n"
        }
        let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func rasterize(page: PDFPage, bounds: CGRect) -> CGImage? {
        let scale: CGFloat = 2.0
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        guard let context = NSGraphicsContext.current?.cgContext else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private static func recognizeText(cgImage: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observations = request.results else { return nil }
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        let joined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }
}
