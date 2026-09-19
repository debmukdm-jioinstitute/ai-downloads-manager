import Foundation

/// A descriptive filename for a file Nest has already looked at — the
/// "you already downloaded it and it's just IMG_4821.pdf" problem. Prefers
/// the AI's own suggestion (set when a local classification was unsure
/// enough to escalate to it — see FileIngestPipeline), since that reads the
/// document's actual content. But AI only ever runs on that unsure minority
/// of files (a real Ollama pass measured at ~90s/file made escalating on
/// every file impractical), so most files never get one — this falls back
/// to a template built from the same structured fields local, offline
/// classification (ClassificationEngine) already extracts for every file,
/// so a useful suggestion is available library-wide, not just for the rare
/// AI-escalated document.
enum FilenameSuggestionEngine {
    static func suggest(for file: FileRecord) -> String? {
        if let ai = file.suggestedFilename, !ai.isEmpty {
            return ai
        }
        return localSuggestion(for: file)
    }

    /// ClassificationEngine's own fallback document types for files it has
    /// no real content signal for — assigned purely from the file extension
    /// ("image", "archive", "video", ...) or, for "screenshot", from the
    /// filename already following a naming convention. None of these say
    /// anything a rename would improve on, so they don't count as signal.
    private static let genericDocumentTypes: Set<String> = [
        "image", "archive", "disk image", "installer package", "audio", "video",
        "presentation", "configuration file", "source code", "spreadsheet",
        "document", "screenshot"
    ]

    private static func localSuggestion(for file: FileRecord) -> String? {
        let specificDocType = file.detectedDocumentType.flatMap { type -> String? in
            let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
            return genericDocumentTypes.contains(trimmed.lowercased()) ? nil : trimmed
        }

        // Only offer a suggestion when there's real signal to build it from —
        // otherwise this would just restate the category on every plain
        // file (or, worse, rename every unremarkable photo to "Image.png"),
        // which is noise rather than something worth renaming to.
        guard file.detectedVendor != nil || specificDocType != nil
            || file.detectedDate != nil || file.detectedDueDate != nil else {
            return nil
        }

        var parts: [String] = []
        if let specificDocType, !specificDocType.isEmpty {
            parts.append(specificDocType.capitalized)
        } else if let subcategory = file.subcategory {
            parts.append(subcategory)
        } else {
            parts.append(file.category)
        }
        if let vendor = file.detectedVendor, !vendor.isEmpty {
            parts.append(vendor)
        }
        if let date = file.detectedDate ?? file.detectedDueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            parts.append(formatter.string(from: date))
        }
        guard !parts.isEmpty else { return nil }

        let base = FilenameSanitizer.sanitize(parts.joined(separator: " - "))
        return file.fileExtension.isEmpty ? base : "\(base).\(file.fileExtension)"
    }
}
