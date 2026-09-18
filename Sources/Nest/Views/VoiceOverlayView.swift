import SwiftUI

/// A small floating HUD shown while "Talk to Nest" is active, overlaid on
/// whatever screen the user is currently on.
struct VoiceOverlayView: View {
    @ObservedObject var coordinator: VoiceCoordinator

    var body: some View {
        if coordinator.overlay != .hidden {
            VStack(spacing: 10) {
                content
            }
            .padding(16)
            .frame(width: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 12)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.25), value: coordinator.overlay)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.overlay {
        case .hidden:
            EmptyView()
        case .listening:
            Label("Listening…", systemImage: "waveform")
                .font(.headline)
            Text("Say what you're looking for.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .processing(let text):
            Label("Heard you", systemImage: "checkmark.circle")
                .font(.headline)
            Text("\"\(text)\"")
                .font(.callout)
                .multilineTextAlignment(.center)
        case .done(let text):
            Label("Searching Nest", systemImage: "magnifyingglass")
                .font(.headline)
            Text("\"\(text)\"")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .failed(let message):
            Label("Talk to Nest", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
