import Foundation

/// Groups file extensions into broad type buckets (Documents, Spreadsheets,
/// Images, Code, ...) for browsing by file type — a different, orthogonal
/// axis from CategoryTaxonomy's content-based classification (Finance,
/// Education, ...). A single PDF invoice shows up under both: "Finance /
/// Invoices" in Categories, and "Documents / pdf" here.
enum FileTypeTaxonomy {
    static let groups: [(name: String, extensions: [String])] = [
        ("Documents", ["pdf", "docx", "doc", "rtf", "txt", "md", "html", "htm", "pages"]),
        ("Spreadsheets", ["xlsx", "xls", "csv", "tsv", "numbers"]),
        ("Presentations", ["pptx", "ppt", "key"]),
        ("Images", ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"]),
        ("Design", ["psd", "ai", "svg", "sketch", "fig", "xd"]),
        ("Code", ["swift", "py", "js", "ts", "tsx", "jsx", "go", "rs", "java", "kt", "c", "h", "cpp", "hpp", "cs", "rb", "php", "sh", "json", "yaml", "yml", "sql"]),
        ("Audio", ["mp3", "wav", "flac", "m4a", "aac"]),
        ("Video", ["mp4", "mov", "avi", "mkv", "webm"]),
        ("Archives", ["zip", "dmg", "tar", "gz", "rar", "7z"])
    ]

    private static let extensionToGroup: [String: String] = {
        var map: [String: String] = [:]
        for group in groups {
            for ext in group.extensions { map[ext] = group.name }
        }
        return map
    }()

    static let allGroupNames: [String] = groups.map(\.name) + ["Other"]

    static func group(forExtension ext: String) -> String {
        extensionToGroup[ext.lowercased()] ?? "Other"
    }
}
