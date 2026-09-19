import SwiftUI

/// Browse by file type (Documents, Images, Code, ...) rather than by content
/// category — e.g. "show me every spreadsheet" regardless of whether it's a
/// budget, a syllabus, or a research dataset.
struct FileTypesView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFile: FileRecord?

    var body: some View {
        // Same single-pass grouping approach as CategoriesView — group once,
        // not once per section, so this stays responsive at library scale.
        let files = appState.allFiles()
        let byGroup = Dictionary(grouping: files, by: { FileTypeTaxonomy.group(forExtension: $0.fileExtension) })

        List {
            ForEach(FileTypeTaxonomy.allGroupNames, id: \.self) { groupName in
                let filesInGroup = byGroup[groupName] ?? []
                if !filesInGroup.isEmpty {
                    let byExtension = Dictionary(grouping: filesInGroup, by: \.fileExtension)
                    Section("\(groupName) (\(filesInGroup.count))") {
                        ForEach(byExtension.keys.sorted(), id: \.self) { ext in
                            let extFiles = byExtension[ext] ?? []
                            DisclosureGroup("\(ext.uppercased()) (\(extFiles.count))") {
                                ForEach(extFiles) { file in
                                    FileRow(file: file)
                                        .onTapGesture { selectedFile = file }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("File Types")
    }
}
