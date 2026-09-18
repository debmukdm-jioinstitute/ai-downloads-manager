import SwiftUI

struct AIConsentSheet: View {
    let host: String
    let onEnable: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(.tint)
            Text("AI processing is enabled. Text extracted from your files will be sent to a local AI model running on this Mac (Ollama, at \(host)) to classify and understand them.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Text("Nothing is uploaded to the internet — the model runs entirely on your machine, is free, and has no usage limit. Files themselves are never sent, only extracted text. You can disable this anytime in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            HStack(spacing: 12) {
                Button("Continue Without AI", action: onDecline)
                Button("Enable AI", action: onEnable).buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 460)
    }
}
