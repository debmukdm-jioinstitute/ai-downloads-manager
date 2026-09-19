import SwiftUI

@main
struct NestApp: App {
    @StateObject private var appState: AppState
    @StateObject private var voiceCoordinator: VoiceCoordinator

    init() {
        let store = LibraryStore()
        let state = AppState(store: store)
        _appState = StateObject(wrappedValue: state)
        _voiceCoordinator = StateObject(wrappedValue: VoiceCoordinator(appState: state))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(voiceCoordinator)
                .frame(minWidth: 900, minHeight: 600)
                .overlay(alignment: .bottom) {
                    VoiceOverlayView(coordinator: voiceCoordinator)
                }
                .onAppear {
                    voiceCoordinator.start()
                    // Headless verification hooks only, never set by a normal
                    // Finder/Dock launch: `NEST_ADD_FOLDER=<path>` adds a
                    // watched folder the same way Settings' "Add Folder..."
                    // does, and `NEST_FORCE_RESCAN=1` triggers the same
                    // rescan as "Rescan Now" — both exist because GUI
                    // automation of this app's custom SwiftUI list rows is
                    // unreliable for verification.
                    if let folderPath = ProcessInfo.processInfo.environment["NEST_ADD_FOLDER"] {
                        appState.addWatchedFolder(URL(fileURLWithPath: folderPath))
                        FileHandle.standardError.write("NEST_DEBUG: added folder \(folderPath)\n".data(using: .utf8)!)
                    }
                    if ProcessInfo.processInfo.environment["NEST_FORCE_RESCAN"] == "1" {
                        FileHandle.standardError.write("NEST_DEBUG: env var seen, watchedFolders=\(appState.watchedFolders.map(\.path))\n".data(using: .utf8)!)
                        for folder in appState.watchedFolders {
                            let listing = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                            FileHandle.standardError.write("NEST_DEBUG: \(folder.path) listing count=\(listing?.count ?? -1)\n".data(using: .utf8)!)
                            appState.scanExistingFiles(in: folder)
                        }
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.hasCompletedOnboarding {
            MainWindowView()
        } else {
            OnboardingView()
        }
    }
}
