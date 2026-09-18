import SwiftUI
import AppKit

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var chosenFolder: URL?
    @State private var step: Step = .folder

    enum Step {
        case folder
        case aiSetup
    }

    var body: some View {
        switch step {
        case .folder:
            folderStep
        case .aiSetup:
            aiSetupStep
        }
    }

    private var folderStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "tray.full.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("AI Downloads Manager")
                .font(.largeTitle.bold())

            Text("Your Downloads folder, automatically understood.")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                featureRow("magnifyingglass", "Find files using natural language")
                featureRow("square.grid.2x2", "Automatically categorize downloads")
                featureRow("doc.text.magnifyingglass", "Detect invoices, receipts, reports, assignments, screenshots, and more")
                featureRow("folder.badge.gearshape", "Organize files without deleting anything")
                featureRow("hand.raised", "Keep control over what gets moved")
            }
            .padding(.top, 8)
            .frame(maxWidth: 420, alignment: .leading)

            if let chosenFolder {
                Text("Selected: \(chosenFolder.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Choose Downloads Folder") { chooseFolder() }
                    .buttonStyle(.bordered)

                Button("Continue") {
                    if let chosenFolder {
                        appState.selectFolder(chosenFolder)
                        step = .aiSetup
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(chosenFolder == nil)
            }
            .padding(.bottom, 40)
        }
        .padding(40)
        .onAppear {
            chosenFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        }
    }

    private var aiSetupStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Set up local AI?")
                .font(.title.bold())
            Text("This app can classify your files with a free AI model that runs entirely on this Mac (Ollama) — no account, no API key, no usage limit, nothing ever leaves your machine. Setup is automatic and only needs to happen once.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            OllamaSetupStatusView(
                coordinator: appState.ollamaSetup,
                host: appState.ollamaHost,
                model: appState.ollamaModel,
                autoStart: true,
                onReady: { enableAndFinish() }
            )
            .frame(maxWidth: 460)

            Spacer()

            Button("Skip — I'll set this up later", action: declineAndFinish)
                .padding(.bottom, 40)
        }
        .padding(40)
    }

    private func enableAndFinish() {
        appState.aiEnabled = true
        appState.hasSeenAIConsent = true
        appState.hasCompletedOnboarding = true
    }

    /// Skip always means decline, even if setup happened to reach "ready" in
    /// the background (e.g. Ollama was already installed and running) before
    /// the user tapped this — an explicit Skip must never leave AI enabled.
    private func declineAndFinish() {
        appState.aiEnabled = false
        appState.hasSeenAIConsent = true
        appState.hasCompletedOnboarding = true
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 20)
            Text(text)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if panel.runModal() == .OK, let url = panel.url {
            chosenFolder = url
        }
    }
}
