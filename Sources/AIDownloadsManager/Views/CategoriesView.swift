import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFile: FileRecord?
    @State private var expanded: Set<String> = []

    var body: some View {
        List {
            ForEach(CategoryTaxonomy.allCategories, id: \.self) { category in
                let filesInCategory = appState.allFiles().filter { $0.category == category }
                Section("\(category) (\(filesInCategory.count))") {
                    ForEach(CategoryTaxonomy.subcategories(for: category), id: \.self) { sub in
                        let subFiles = filesInCategory.filter { $0.subcategory == sub }
                        if !subFiles.isEmpty {
                            DisclosureGroup("\(sub) (\(subFiles.count))") {
                                ForEach(subFiles) { file in
                                    FileRow(file: file)
                                        .onTapGesture { selectedFile = file }
                                }
                            }
                        }
                    }
                }
            }

            let needsReview = appState.allFiles().filter { $0.processingStatus == .needsReview }
            if !needsReview.isEmpty {
                Section("Needs Review (\(needsReview.count))") {
                    ForEach(needsReview) { file in
                        FileRow(file: file).onTapGesture { selectedFile = file }
                    }
                }
            }
        }
        .navigationTitle("Categories")
    }
}
