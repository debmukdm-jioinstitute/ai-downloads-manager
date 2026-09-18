import Foundation
import CryptoKit

enum HashService {
    /// Streaming SHA-256 so large files don't get fully loaded into memory.
    static func sha256(ofFileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        let chunkSize = 1024 * 1024
        while true {
            guard let data = try? handle.read(upToCount: chunkSize), !data.isEmpty else { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
