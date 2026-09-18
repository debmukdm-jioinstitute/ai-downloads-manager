import SwiftUI

@main
struct AIDownloadsManagerApp: App {
    @StateObject private var appState: AppState

    init() {
        let store = LibraryStore()
        _appState = StateObject(wrappedValue: AppState(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
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
