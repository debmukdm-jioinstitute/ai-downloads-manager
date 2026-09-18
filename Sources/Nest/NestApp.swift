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
                .onAppear { voiceCoordinator.start() }
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
