import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKeyInput: String = ""
    @State private var showingConsent = false
    @State private var saveConfirmation: String?

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

            Section("AI Processing") {
                Toggle("Enable AI classification (Claude)", isOn: Binding(
                    get: { appState.aiEnabled },
                    set: { newValue in
                        if newValue && !appState.hasSeenAIConsent {
                            showingConsent = true
                        } else {
                            appState.aiEnabled = newValue
                        }
                    }
                ))

                SecureField("Claude API key", text: $apiKeyInput)
                HStack {
                    Button("Save Key") {
                        KeychainService.saveAPIKey(apiKeyInput)
                        saveConfirmation = "API key saved to Keychain."
                        apiKeyInput = ""
                    }
                    .disabled(apiKeyInput.isEmpty)

                    Button("Remove Key", role: .destructive) {
                        KeychainService.deleteAPIKey()
                        appState.aiEnabled = false
                        saveConfirmation = "API key removed."
                    }
                    .disabled(!KeychainService.hasAPIKey)
                }

                Text(KeychainService.hasAPIKey ? "A key is stored securely in Keychain." : "No key stored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let saveConfirmation {
                    Text(saveConfirmation).font(.caption).foregroundStyle(.green)
                }

                Text("Local processing (metadata, hashing, PDF text, OCR) always runs on-device. When AI is enabled, only extracted text from a file — never the file itself — is sent to Claude to classify it.")
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
