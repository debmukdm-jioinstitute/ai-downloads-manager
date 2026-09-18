import Foundation
import CoreServices

/// Watches a directory with FSEvents and reports files once they look
/// "settled" (not still growing, not a browser partial-download artifact).
final class FolderMonitor {
    private var stream: FSEventStreamRef?
    private let path: String
    private let onFilesChanged: ([String]) -> Void
    private let queue = DispatchQueue(label: "com.aidownloadsmanager.foldermonitor")

    /// Extensions/suffixes that mark an in-progress download. These files are
    /// ignored entirely until they disappear (renamed to their final name).
    private static let partialDownloadMarkers = [".crdownload", ".download", ".part", ".tmp"]

    init(folderURL: URL, onFilesChanged: @escaping ([String]) -> Void) {
        self.path = folderURL.path
        self.onFilesChanged = onFilesChanged
    }

    func start() {
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let pathsToWatch = [path] as CFArray
        let callback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, _, _ in
            guard let info = clientCallBackInfo else { return }
            let monitor = Unmanaged<FolderMonitor>.fromOpaque(info).takeUnretainedValue()
            guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
            monitor.handleRawEvents(paths)
        }
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func handleRawEvents(_ paths: [String]) {
        let candidates = paths.filter { p in
            !Self.partialDownloadMarkers.contains(where: { p.hasSuffix($0) })
        }
        guard !candidates.isEmpty else { return }
        // Debounce: give the OS a moment to finish writing before we report.
        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            let settled = candidates.filter { self.isSettled(path: $0) }
            if !settled.isEmpty {
                DispatchQueue.main.async { self.onFilesChanged(settled) }
            }
        }
    }

    /// A file is "settled" if it exists, isn't zero-length-and-still-growing,
    /// and its size hasn't changed across a short sampling window.
    private func isSettled(path: String) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else { return false }
        guard let size1 = try? fm.attributesOfItem(atPath: path)[.size] as? Int64 else { return false }
        Thread.sleep(forTimeInterval: 0.4)
        guard fm.fileExists(atPath: path),
              let size2 = try? fm.attributesOfItem(atPath: path)[.size] as? Int64 else { return false }
        return size1 == size2
    }

    deinit {
        stop()
    }
}
