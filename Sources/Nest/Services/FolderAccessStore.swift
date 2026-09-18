import Foundation

/// Persists a security-scoped bookmark for the user-chosen Downloads folder so
/// the app can keep access across launches without requesting broad filesystem
/// permission. Falls back gracefully when the app isn't sandboxed (SPM debug runs).
enum FolderAccessStore {
    private static let bookmarkKey = "downloadsFolderBookmark"
    private static let pathKey = "downloadsFolderPath"

    static func save(url: URL) {
        UserDefaults.standard.set(url.path, forKey: pathKey)
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        }
    }

    /// Resolves the stored folder, starting security-scoped access if a bookmark
    /// exists. Caller is responsible for calling `stopAccessingSecurityScopedResource()`
    /// only if it wants to release access early; the app generally holds it for its lifetime.
    static func resolve() -> URL? {
        if let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if isStale {
                    // Self-heal: re-save a fresh bookmark now that we have a
                    // resolved URL, rather than silently using a rotting one
                    // on every future launch.
                    save(url: url)
                }
                if url.startAccessingSecurityScopedResource() {
                    return url
                }
                // Access explicitly failed (revoked, folder moved/deleted) —
                // don't return this URL as if it were usable; fall through to
                // the plain-path fallback below instead.
            }
        }
        if let path = UserDefaults.standard.string(forKey: pathKey) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    static var hasSavedFolder: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil || UserDefaults.standard.string(forKey: pathKey) != nil
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: pathKey)
    }
}
