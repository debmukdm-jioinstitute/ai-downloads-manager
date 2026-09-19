import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFile: FileRecord?

    var body: some View {
        // Grouped once per render instead of re-filtering the full (possibly
        // thousand-plus record) library once per category AND again per
        // subcategory — that repeated O(n) work per DisclosureGroup was what
        // made expanding a category feel unresponsive.
        let files = appState.allFiles()
        let byCategory = Dictionary(grouping: files, by: \.category)

        List {
            ForEach(CategoryTaxonomy.allCategories, id: \.self) { category in
                let filesInCategory = byCategory[category] ?? []
                let bySubcategory = Dictionary(grouping: filesInCategory, by: { $0.subcategory ?? "" })
                Section("\(category) (\(filesInCategory.count))") {
                    ForEach(CategoryTaxonomy.subcategories(for: category), id: \.self) { sub in
                        let subFiles = bySubcategory[sub] ?? []
                        if !subFiles.isEmpty {
                            DisclosureGroup("\(sub) (\(subFiles.count))") {
                                ForEach(subFiles) { file in
                                    FileRow(file: file, onSelect: { selectedFile = file })
                                }
                            }
                        }
                    }
                }
            }

            let needsReview = files.filter { $0.processingStatus == .needsReview }
            if !needsReview.isEmpty {
                Section("Needs Review (\(needsReview.count))") {
                    ForEach(needsReview) { file in
                        FileRow(file: file, onSelect: { selectedFile = file })
                    }
                }
            }
        }
        .navigationTitle("Categories")
    }
}
