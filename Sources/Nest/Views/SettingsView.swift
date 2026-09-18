import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var voiceCoordinator: VoiceCoordinator
    @State private var showingConsent = false
    @State private var availableModels: [String] = []
    @State private var voicePermissionDenied = false

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

            Section("Expiry Notifications") {
                Toggle("90 days before", isOn: offsetBinding(90))
                Toggle("30 days before", isOn: offsetBinding(30))
                Toggle("7 days before", isOn: offsetBinding(7))
                Toggle("On expiry", isOn: $appState.notifyOnExpiry)
                Toggle("Notify only high-confidence detections", isOn: $appState.notifyOnlyHighConfidence)

                if !appState.notificationsAuthorized {
                    Button("Enable Notifications") {
                        Task { await appState.requestNotificationAuthorization() }
                    }
                }

                Text("Notifications are scheduled locally on this Mac for expiry, deadline, and renewal dates the app finds in your documents. Nothing is sent anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Talk to Nest") {
                Toggle("Enable Voice Commands", isOn: Binding(
                    get: { appState.voiceCommandsEnabled },
                    set: { newValue in
                        if newValue {
                            Task {
                                let granted = await VoiceCommandService.requestAuthorization()
                                appState.voiceCommandsEnabled = granted
                                voicePermissionDenied = !granted
                                voiceCoordinator.refresh()
                            }
                        } else {
                            appState.voiceCommandsEnabled = false
                            voiceCoordinator.refresh()
                        }
                    }
                ))

                if voicePermissionDenied {
                    Text("Microphone or Speech Recognition access was denied. Enable both for Nest in System Settings ▸ Privacy & Security.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Toggle("Also listen for \"Hey Nest\"", isOn: Binding(
                    get: { appState.wakeWordEnabled },
                    set: { newValue in
                        appState.wakeWordEnabled = newValue
                        voiceCoordinator.refresh()
                    }
                ))
                .disabled(!appState.voiceCommandsEnabled)

                Toggle("Speak results aloud", isOn: $appState.speakResultsAloud)
                    .disabled(!appState.voiceCommandsEnabled)

                Text("Press Command+Option together anywhere to talk to Nest, or say \"Hey Nest\" if that's turned on. Speech recognition runs on-device when your Mac supports it, and nothing is sent anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                Text("Nest understands, organizes, and helps you search your Downloads folder. Nothing is ever deleted automatically, and files are only moved with your review or explicit rule.")
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
                onReady: {
                    appState.aiEnabled = true
                    appState.hasSeenAIConsent = true
                    showingConsent = false
                },
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

    private func offsetBinding(_ days: Int) -> Binding<Bool> {
        Binding(
            get: { appState.notifyOffsetDays.contains(days) },
            set: { isOn in
                if isOn { appState.notifyOffsetDays.insert(days) } else { appState.notifyOffsetDays.remove(days) }
            }
        )
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
