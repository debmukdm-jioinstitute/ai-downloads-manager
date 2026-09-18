import SwiftUI

struct AIConsentSheet: View {
    let onEnable: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(.tint)
            Text("AI processing is enabled. Text extracted from your files may be sent to Claude to classify and understand them.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Text("Files themselves are never uploaded — only extracted text from documents you choose to have AI-classified. You can disable this anytime in Settings.")
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
