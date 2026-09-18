import SwiftUI
import AppKit

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var chosenFolder: URL?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "tray.full.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("AI Downloads Manager")
                .font(.largeTitle.bold())

            Text("Your Downloads folder, automatically understood.")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                featureRow("magnifyingglass", "Find files using natural language")
                featureRow("square.grid.2x2", "Automatically categorize downloads")
                featureRow("doc.text.magnifyingglass", "Detect invoices, receipts, reports, assignments, screenshots, and more")
                featureRow("folder.badge.gearshape", "Organize files without deleting anything")
                featureRow("hand.raised", "Keep control over what gets moved")
            }
            .padding(.top, 8)
            .frame(maxWidth: 420, alignment: .leading)

            if let chosenFolder {
                Text("Selected: \(chosenFolder.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Choose Downloads Folder") { chooseFolder() }
                    .buttonStyle(.bordered)

                Button("Continue") {
                    if let chosenFolder {
                        appState.chooseFolder(chosenFolder)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(chosenFolder == nil)
            }
            .padding(.bottom, 40)
        }
        .padding(40)
        .onAppear {
            chosenFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 20)
            Text(text)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if panel.runModal() == .OK, let url = panel.url {
            chosenFolder = url
        }
    }
}
