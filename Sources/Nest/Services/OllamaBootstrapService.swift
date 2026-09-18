import Foundation

/// Everything needed to go from "nothing installed" to "local AI ready" without
/// the user ever opening Terminal: find Ollama (or Homebrew to install it),
/// start the server, and stream-pull a model via Ollama's own HTTP API.
enum OllamaBootstrapService {

    private static let ollamaBinaryPaths = [
        "/opt/homebrew/bin/ollama",
        "/usr/local/bin/ollama",
        "/Applications/Ollama.app/Contents/Resources/ollama"
    ]
    private static let brewBinaryPaths = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew"
    ]

    static func findOllamaBinary() -> String? {
        ollamaBinaryPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func findBrewBinary() -> String? {
        brewBinaryPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func isServerRunning(host: String) async -> Bool {
        guard let url = URL(string: normalized(host) + "/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }

    static func waitForServer(host: String, timeout: TimeInterval = 25) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await isServerRunning(host: host) { return true }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }

    /// Launches `ollama serve` detached in the background. Safe to call even
    /// if a server is already running elsewhere — the port bind will just fail
    /// silently and the existing server keeps serving.
    static func startServer(ollamaPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ollamaPath)
        process.arguments = ["serve"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    /// Runs `brew install ollama`, streaming combined stdout/stderr to `output`.
    /// Only ever invoked from an explicit user tap — never automatically.
    static func installViaHomebrew(brewPath: String, output: @escaping (String) -> Void) async throws {
        try await runProcess(executable: brewPath, arguments: ["install", "ollama"], output: output)
    }

    enum PullEvent {
        case progress(status: String, fraction: Double?)
        case done
    }

    /// Streams `POST /api/pull`, translating Ollama's NDJSON progress events
    /// into a simple fraction the UI can show as a progress bar.
    static func pullModel(host: String, model: String, onEvent: @escaping (PullEvent) -> Void) async throws {
        guard let url = URL(string: normalized(host) + "/api/pull") else {
            throw AIServiceError.network("Invalid Ollama host.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "stream": true])

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIServiceError.network("HTTP \(status) while pulling model \(model).")
        }

        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let error = json["error"] as? String {
                throw AIServiceError.network(error)
            }
            let status = json["status"] as? String ?? "Working..."
            if let completed = json["completed"] as? Double, let total = json["total"] as? Double, total > 0 {
                onEvent(.progress(status: status, fraction: completed / total))
            } else {
                onEvent(.progress(status: status, fraction: nil))
            }
        }
        onEvent(.done)
    }

    private static func normalized(_ host: String) -> String {
        host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func runProcess(executable: String, arguments: [String], output: @escaping (String) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                output(text)
            }
            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AIServiceError.network("Exited with status \(proc.terminationStatus)."))
                }
            }
            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
