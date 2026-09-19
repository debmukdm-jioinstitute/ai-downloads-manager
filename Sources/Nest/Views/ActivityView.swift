import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(appState.recentActivity()) { event in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon(for: event.kind))
                    .foregroundStyle(color(for: event.kind))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.message)
                    if let filename = event.filename {
                        Text(filename).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(event.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .navigationTitle("Activity")
    }

    private func icon(for kind: ActivityKind) -> String {
        switch kind {
        case .detected: return "eye"
        case .processed: return "checkmark.circle"
        case .classified: return "tag"
        case .duplicate: return "doc.on.doc.fill"
        case .moved: return "arrow.right.circle"
        case .renamed: return "pencil.circle"
        case .deleted: return "trash"
        case .undone: return "arrow.uturn.backward.circle"
        case .error: return "exclamationmark.triangle"
        case .aiDisabled: return "sparkles.slash"
        case .aiEnabled: return "sparkles"
        }
    }

    private func color(for kind: ActivityKind) -> Color {
        switch kind {
        case .error, .deleted: return .red
        case .duplicate: return .orange
        default: return .secondary
        }
    }
}
