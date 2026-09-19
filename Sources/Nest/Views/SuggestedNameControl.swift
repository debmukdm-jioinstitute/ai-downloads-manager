import SwiftUI

/// Inline "AI suggests: <name> [Apply Changes]" control, shared between the
/// file detail pane and every file list row so a user never has to open a
/// file just to accept a better name for it. Self-contained (own state, own
/// tweak-before-confirm sheet) so embedding it in a list row costs the
/// caller nothing beyond dropping it into their layout.
struct SuggestedNameControl: View {
    @EnvironmentObject var appState: AppState
    let file: FileRecord
    /// Smaller type/controls for use inside a list row rather than the
    /// spacious detail pane.
    var compact: Bool = false

    @State private var showingTweak = false
    @State private var appliedName = ""
    @State private var tweakedName = ""
    @State private var errorMessage: String?

    private var suggestion: String? {
        guard let suggested = FilenameSuggestionEngine.suggest(for: file), suggested != file.filename else { return nil }
        return suggested
    }

    var body: some View {
        if let suggestion {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(compact ? .caption2 : .body)
                        .foregroundStyle(.secondary)
                    Text(suggestion)
                        .font(compact ? .caption : .callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Apply Changes") { apply(suggestion) }
                        .controlSize(compact ? .small : .regular)
                }
                if let errorMessage {
                    Text(errorMessage).font(.caption2).foregroundStyle(.red)
                }
            }
            .sheet(isPresented: $showingTweak) { tweakSheet }
        }
    }

    private func apply(_ suggestion: String) {
        errorMessage = nil
        do {
            try appState.organizer()?.rename(file, to: suggestion)
        } catch FileOrganizerError.sourceMissing {
            appState.removeMissingFile(file)
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        // rename() sanitizes and de-duplicates the requested name, so what
        // actually landed on disk (file.filename, now updated) may differ
        // slightly from the raw suggestion — that's what gets offered for
        // one more tweak, not the pre-sanitized string.
        appliedName = file.filename
        tweakedName = appliedName
        showingTweak = true
    }

    private var tweakSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name Applied").bold()
            Text("Renamed to \u{201C}\(appliedName)\u{201D}. Want to tweak the wording or extension before confirming?")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Filename", text: $tweakedName)
            HStack {
                Spacer()
                Button("Confirm") {
                    if tweakedName != appliedName {
                        do {
                            try appState.organizer()?.rename(file, to: tweakedName)
                        } catch FileOrganizerError.sourceMissing {
                            appState.removeMissingFile(file)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    showingTweak = false
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 380)
    }
}
