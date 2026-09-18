import Quartz
import AppKit

/// Drives the shared system Quick Look panel — the same one Finder uses for
/// spacebar preview — for a single file at a time. `NSURL` already conforms
/// to `QLPreviewItem` (provided by the QuickLookUI/Quartz framework), so no
/// custom preview-item wrapper is needed.
final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookCoordinator()
    private var currentURL: NSURL?

    /// Space bar behavior, matching Finder: press once to preview, press
    /// again on the same file to dismiss.
    func toggle(url: URL) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible, currentURL == (url as NSURL) {
            close()
        } else {
            show(url: url)
        }
    }

    /// Opens (or updates, if already open) the panel for `url` — used to keep
    /// Quick Look following the selection live, the way Finder does when you
    /// arrow through files with the panel already open.
    func show(url: URL) {
        guard let panel = QLPreviewPanel.shared() else { return }
        currentURL = url as NSURL
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        QLPreviewPanel.shared()?.orderOut(nil)
        currentURL = nil
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        currentURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        currentURL
    }
}
