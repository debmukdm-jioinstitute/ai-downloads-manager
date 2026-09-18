import SwiftUI

struct AllFilesView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFile: FileRecord?
    @State private var filterText = ""

    var files: [FileRecord] {
        let all = appState.allFiles()
        guard !filterText.isEmpty else { return all }
        return all.filter { $0.filename.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Filter by filename", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .padding(10)

            List(files, selection: Binding(get: { selectedFile?.id }, set: { id in
                selectedFile = files.first { $0.id == id }
            })) { file in
                FileRow(file: file).tag(file.id)
            }
        }
        .navigationTitle("All Files (\(files.count))")
    }
}
