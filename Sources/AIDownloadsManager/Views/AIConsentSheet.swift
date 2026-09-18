import SwiftUI

struct AIConsentSheet: View {
    @ObservedObject var setup: OllamaSetupCoordinator
    let host: String
    let model: String
    let onReady: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(.tint)
            Text("Turn on local AI classification?")
                .font(.title3.bold())
            Text("Text extracted from your files will be sent to a free AI model that runs entirely on this Mac (Ollama). Nothing is uploaded to the internet, there's no API key, and there's no usage limit. Setup happens automatically below — it only needs to run once.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            OllamaSetupStatusView(coordinator: setup, host: host, model: model, autoStart: true, onReady: onReady)
                .frame(maxWidth: 420)

            Button("Continue Without AI", action: onDecline)
                .padding(.top, 4)
        }
        .padding(30)
        .frame(width: 480)
    }
}
