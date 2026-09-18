import SwiftUI
import AppKit

/// Shared "make local AI just work" panel — used both in the first-run AI
/// consent step and in Settings, backed by the same `OllamaSetupCoordinator`
/// so a run started from one place is visible from the other.
struct OllamaSetupStatusView: View {
    @ObservedObject var coordinator: OllamaSetupCoordinator
    let host: String
    let model: String
    var autoStart: Bool = false
    var onReady: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusRow

            switch coordinator.stage {
            case .idle:
                Button("Set Up Local AI Automatically") {
                    Task { await coordinator.runAutoSetup(host: host, model: model) }
                }
                .buttonStyle(.borderedProminent)

            case .checking, .startingServer, .installing:
                if case .installing = coordinator.stage, !coordinator.installLog.isEmpty {
                    ScrollView {
                        Text(coordinator.installLog)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 80)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                }

            case .needsInstall(let hasHomebrew):
                Text("Ollama isn't installed yet. It's free, runs entirely on this Mac, and this only needs to happen once.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    if hasHomebrew {
                        Button("Install via Homebrew") {
                            Task { await coordinator.installViaHomebrewThenSetup(host: host, model: model) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button(hasHomebrew ? "Or Download Manually" : "Download Ollama") {
                        NSWorkspace.shared.open(URL(string: "https://ollama.com/download")!)
                    }
                    if !hasHomebrew {
                        Button("I Installed It — Retry") {
                            Task { await coordinator.runAutoSetup(host: host, model: model) }
                        }
                    }
                }

            case .pullingModel(let status, let fraction):
                VStack(alignment: .leading, spacing: 4) {
                    if let fraction {
                        ProgressView(value: fraction)
                    } else {
                        ProgressView()
                    }
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }

            case .ready:
                Label("Local AI is ready — model \"\(model)\" is installed and running.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

            case .failed(let message):
                Text(message).font(.caption).foregroundStyle(.red)
                Button("Retry") {
                    Task { await coordinator.runAutoSetup(host: host, model: model) }
                }
            }
        }
        .onChange(of: coordinator.stage) { _, newStage in
            if newStage == .ready { onReady?() }
        }
        .task {
            if autoStart, coordinator.stage == .idle {
                await coordinator.runAutoSetup(host: host, model: model)
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(label).font(.callout)
        }
    }

    private var icon: String {
        switch coordinator.stage {
        case .idle: return "sparkles"
        case .checking, .startingServer, .installing: return "arrow.triangle.2.circlepath"
        case .needsInstall: return "arrow.down.circle"
        case .pullingModel: return "arrow.down.circle"
        case .ready: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch coordinator.stage {
        case .ready: return .green
        case .failed: return .red
        case .needsInstall: return .orange
        default: return .secondary
        }
    }

    private var label: String {
        switch coordinator.stage {
        case .idle: return "Local AI is not set up yet."
        case .checking: return "Checking for Ollama…"
        case .startingServer: return "Starting Ollama…"
        case .installing: return "Installing Ollama via Homebrew…"
        case .needsInstall: return "Ollama needs to be installed."
        case .pullingModel: return "Downloading model \"\(model)\"…"
        case .ready: return "Ready."
        case .failed: return "Setup couldn't finish."
        }
    }
}
