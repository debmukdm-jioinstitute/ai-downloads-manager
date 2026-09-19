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
                    // Headless verification hook only: `NEST_FORCE_RESCAN=1` lets a
                    // Terminal-launched instance trigger the same rescan as the
                    // Settings "Rescan Now" button, since GUI automation of this
                    // app's custom SwiftUI list rows is unreliable. Never set by a
                    // normal Finder/Dock launch, so it can't fire unintentionally.
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
