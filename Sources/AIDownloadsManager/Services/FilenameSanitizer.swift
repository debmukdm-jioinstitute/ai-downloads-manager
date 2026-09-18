import Foundation

enum FilenameSanitizer {
    private static let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")

    static func sanitize(_ name: String) -> String {
        var cleaned = name.components(separatedBy: forbidden).joined(separator: "-")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { cleaned = "Untitled" }
        if cleaned.hasPrefix(".") { cleaned = "_" + cleaned }
        return String(cleaned.prefix(255))
    }

    /// Returns a filename guaranteed not to collide with an existing file in `directory`,
    /// appending " 2", " 3", etc. before the extension as Finder does.
    static func uniqueFilename(_ desired: String, in directory: URL) -> String {
        let fm = FileManager.default
        var candidate = desired
        var counter = 2
        let ext = (desired as NSString).pathExtension
        let base = ext.isEmpty ? desired : String(desired.dropLast(ext.count + 1))
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            counter += 1
        }
        return candidate
    }
}
