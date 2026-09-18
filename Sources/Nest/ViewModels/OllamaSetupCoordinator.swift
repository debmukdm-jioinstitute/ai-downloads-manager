import Foundation

/// Drives the "make local AI just work" flow: check -> (install if needed) ->
/// start server -> pull model -> ready. Every network/process call is real;
/// the only step that requires a user tap is the Homebrew install itself,
/// since that installs software on their Mac.
@MainActor
final class OllamaSetupCoordinator: ObservableObject {
    enum Stage: Equatable {
        case idle
        case checking
        case needsInstall(hasHomebrew: Bool)
        case installing
        case startingServer
        case pullingModel(status: String, fraction: Double?)
        case ready
        case failed(String)
    }

    @Published private(set) var stage: Stage = .idle
    @Published private(set) var installLog: String = ""

    /// Full automatic path: if the server's already up, just make sure the
    /// model is pulled. Otherwise try to find and start an installed Ollama.
    /// If Ollama isn't installed at all, stop and surface the install step.
    func runAutoSetup(host: String, model: String) async {
        stage = .checking

        if await OllamaBootstrapService.isServerRunning(host: host) {
            await pullAndFinish(host: host, model: model)
            return
        }

        guard let ollamaPath = OllamaBootstrapService.findOllamaBinary() else {
            stage = .needsInstall(hasHomebrew: OllamaBootstrapService.findBrewBinary() != nil)
            return
        }

        stage = .startingServer
        do {
            try OllamaBootstrapService.startServer(ollamaPath: ollamaPath)
        } catch {
            stage = .failed("Couldn't start Ollama: \(error.localizedDescription)")
            return
        }

        guard await OllamaBootstrapService.waitForServer(host: host) else {
            stage = .failed("Ollama didn't respond after starting. Try again, or start it manually.")
            return
        }

        await pullAndFinish(host: host, model: model)
    }

    /// User explicitly tapped "Install via Homebrew" — the only step in this
    /// whole flow that installs anything, so it never runs unprompted.
    func installViaHomebrewThenSetup(host: String, model: String) async {
        guard let brew = OllamaBootstrapService.findBrewBinary() else {
            stage = .failed("Homebrew isn't installed. Download Ollama from ollama.com instead, then tap Retry.")
            return
        }
        stage = .installing
        installLog = ""
        do {
            try await OllamaBootstrapService.installViaHomebrew(brewPath: brew) { [weak self] chunk in
                Task { @MainActor in self?.installLog += chunk }
            }
        } catch {
            stage = .failed("Install failed: \(error.localizedDescription)")
            return
        }
        await runAutoSetup(host: host, model: model)
    }

    private func pullAndFinish(host: String, model: String) async {
        stage = .pullingModel(status: "Starting…", fraction: nil)
        do {
            try await OllamaBootstrapService.pullModel(host: host, model: model) { [weak self] event in
                Task { @MainActor in
                    guard let self else { return }
                    switch event {
                    case .progress(let status, let fraction):
                        self.stage = .pullingModel(status: status, fraction: fraction)
                    case .done:
                        break
                    }
                }
            }
            stage = .ready
        } catch {
            stage = .failed("Couldn't download the model: \(error.localizedDescription)")
        }
    }

    func reset() {
        stage = .idle
        installLog = ""
    }
}
