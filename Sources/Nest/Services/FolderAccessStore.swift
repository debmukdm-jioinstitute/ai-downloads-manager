import Foundation

/// Persists security-scoped bookmarks for every folder Nest watches (not
/// just one) so access survives across launches without needing broad
/// filesystem permission. Falls back to a plain path when the app isn't
/// sandboxed (SPM debug runs).
enum FolderAccessStore {
    private struct StoredFolder: Codable {
        let path: String
        let bookmark: Data?
    }

    private static let foldersKey = "watchedFoldersV2"
    // Pre-multi-folder keys. Only ever read once, to migrate an existing
    // single-folder setup forward without losing it.
    private static let legacyBookmarkKey = "downloadsFolderBookmark"
    private static let legacyPathKey = "downloadsFolderPath"

    static func saveFolders(_ urls: [URL]) {
        let stored = urls.map { url -> StoredFolder in
            let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            return StoredFolder(path: url.path, bookmark: bookmark)
        }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: foldersKey)
        }
    }

    static func addFolder(_ url: URL) {
        var current = resolveAll()
        let standardized = url.standardizedFileURL.path
        guard !current.contains(where: { $0.standardizedFileURL.path == standardized }) else { return }
        current.append(url)
        saveFolders(current)
    }

    static func removeFolder(_ url: URL) {
        let standardized = url.standardizedFileURL.path
        let remaining = resolveAll().filter { $0.standardizedFileURL.path != standardized }
        saveFolders(remaining)
    }

    /// Resolves every stored folder, starting security-scoped access for
    /// each. A folder that's been moved/deleted/had access revoked is
    /// silently dropped rather than surfaced as an error — the user can just
    /// add it again from Settings.
    static func resolveAll() -> [URL] {
        migrateLegacyIfNeeded()
        guard let data = UserDefaults.standard.data(forKey: foldersKey),
              let stored = try? JSONDecoder().decode([StoredFolder].self, from: data) else { return [] }

        var resolved: [URL] = []
        var needsResave = false
        for entry in stored {
            if let bookmarkData = entry.bookmark {
                var isStale = false
                if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    if isStale { needsResave = true }
                    if url.startAccessingSecurityScopedResource() {
                        resolved.append(url)
                        continue
                    }
                }
            }
            // No bookmark, or it failed to resolve/access — fall back to the
            // plain path (always the case for non-sandboxed debug runs).
            resolved.append(URL(fileURLWithPath: entry.path))
        }
        if needsResave { saveFolders(resolved) }
        return resolved
    }

    static var hasSavedFolders: Bool {
        if UserDefaults.standard.data(forKey: foldersKey) != nil { return true }
        return UserDefaults.standard.data(forKey: legacyBookmarkKey) != nil
            || UserDefaults.standard.string(forKey: legacyPathKey) != nil
    }

    private static func migrateLegacyIfNeeded() {
        guard UserDefaults.standard.data(forKey: foldersKey) == nil else { return }
        var legacyURL: URL?
        if let bookmark = UserDefaults.standard.data(forKey: legacyBookmarkKey) {
            var isStale = false
            legacyURL = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
        if legacyURL == nil, let path = UserDefaults.standard.string(forKey: legacyPathKey) {
            legacyURL = URL(fileURLWithPath: path)
        }
        guard let legacyURL else { return }
        saveFolders([legacyURL])
        UserDefaults.standard.removeObject(forKey: legacyBookmarkKey)
        UserDefaults.standard.removeObject(forKey: legacyPathKey)
    }
}
