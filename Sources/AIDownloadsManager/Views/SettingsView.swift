import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingConsent = false
    @State private var availableModels: [String] = []

    var body: some View {
        Form {
            Section("Downloads Folder") {
                HStack {
                    Text(appState.downloadsFolder?.path ?? "Not set")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Change...") { chooseFolder() }
                }
            }

            Section("AI Processing (Free, Local, Unlimited)") {
                Toggle("Enable AI classification (Ollama)", isOn: Binding(
                    get: { appState.aiEnabled },
                    set: { newValue in
                        if newValue && appState.ollamaSetup.stage != .ready {
                            showingConsent = true
                        } else {
                            appState.aiEnabled = newValue
                        }
                    }
                ))

                OllamaSetupStatusView(coordinator: appState.ollamaSetup, host: appState.ollamaHost, model: appState.ollamaModel)

                DisclosureGroup("Advanced") {
                    TextField("Ollama host", text: $appState.ollamaHost)
                    TextField("Model (e.g. llama3.2:1b, mistral, qwen2.5)", text: $appState.ollamaModel)
                    if !availableModels.isEmpty {
                        Picker("Installed models", selection: $appState.ollamaModel) {
                            ForEach(availableModels, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Button("Refresh installed models") {
                        Task { availableModels = await OllamaAIService.listModels(host: appState.ollamaHost) ?? [] }
                    }
                }

                Text("Local processing (metadata, hashing, PDF text, OCR) always runs on-device. When AI is enabled, extracted text is sent to Ollama — a free, open-source model running entirely on this Mac. Nothing ever leaves your machine, and there's no API key, quota, or per-use cost.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                Text("AI Downloads Manager understands, organizes, and helps you search your Downloads folder. Nothing is ever deleted automatically, and files are only moved with your review or explicit rule.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showingConsent) {
            AIConsentSheet(
                setup: appState.ollamaSetup,
                host: appState.ollamaHost,
                model: appState.ollamaModel,
                onReady: { showingConsent = false },
                onDecline: {
                    appState.hasSeenAIConsent = true
                    appState.aiEnabled = false
                    showingConsent = false
                }
            )
        }
        .task {
            availableModels = await OllamaAIService.listModels(host: appState.ollamaHost) ?? []
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.chooseFolder(url)
        }
    }
}
