import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingConsent = false
    @State private var availableModels: [String] = []
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTesting = false

    enum ConnectionStatus {
        case unknown, reachable, unreachable
    }

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
                        if newValue && !appState.hasSeenAIConsent {
                            showingConsent = true
                        } else {
                            appState.aiEnabled = newValue
                        }
                    }
                ))

                TextField("Ollama host", text: $appState.ollamaHost)
                TextField("Model (e.g. llama3.2, mistral, qwen2.5)", text: $appState.ollamaModel)

                HStack {
                    Button("Test Connection") { Task { await testConnection() } }
                        .disabled(isTesting)
                    if isTesting {
                        ProgressView().controlSize(.small)
                    }
                    statusView
                }

                if !availableModels.isEmpty {
                    Picker("Installed models", selection: $appState.ollamaModel) {
                        ForEach(availableModels, id: \.self) { Text($0).tag($0) }
                    }
                }

                Text("Local processing (metadata, hashing, PDF text, OCR) always runs on-device. When AI is enabled, extracted text is sent to Ollama — a free, open-source model running entirely on this Mac at \(appState.ollamaHost). Nothing ever leaves your machine, and there's no API key, quota, or per-use cost. Install Ollama from ollama.com and run \"ollama pull \(appState.ollamaModel.isEmpty ? "llama3.2" : appState.ollamaModel)\" if you haven't already.")
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
                host: appState.ollamaHost,
                onEnable: {
                    appState.hasSeenAIConsent = true
                    appState.aiEnabled = true
                    showingConsent = false
                },
                onDecline: {
                    appState.hasSeenAIConsent = true
                    appState.aiEnabled = false
                    showingConsent = false
                }
            )
        }
        .task { await testConnection() }
    }

    @ViewBuilder
    private var statusView: some View {
        switch connectionStatus {
        case .unknown:
            EmptyView()
        case .reachable:
            Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
        case .unreachable:
            Label("Not reachable", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
        }
    }

    private func testConnection() async {
        isTesting = true
        let models = await OllamaAIService.listModels(host: appState.ollamaHost)
        availableModels = models ?? []
        connectionStatus = models == nil ? .unreachable : .reachable
        isTesting = false
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
