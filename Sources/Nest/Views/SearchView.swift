import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedFile: FileRecord?
    @State private var query = ""
    @State private var results: [FileRecord] = []
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search your Downloads...", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit(runSearch)
                if isSearching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            .padding(12)

            if let searchError {
                Text(searchError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
            }

            List(results, selection: Binding(get: { selectedFile?.id }, set: { id in
                selectedFile = results.first { $0.id == id }
            })) { file in
                FileRow(file: file).tag(file.id)
            }
        }
        .navigationTitle("Search")
        .onAppear { results = appState.allFiles() }
        .onChange(of: appState.pendingVoiceQuery) { _, pending in
            guard let pending else { return }
            query = pending
            runSearch()
            appState.pendingVoiceQuery = nil
        }
    }

    private func runSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = appState.allFiles()
            return
        }
        isSearching = true
        searchError = nil
        Task {
            var filters: AISearchFilters?
            if appState.aiEnabled {
                do {
                    filters = try await appState.makeAIService().interpretSearchQuery(query)
                } catch {
                    searchError = "AI couldn't interpret the query; showing local search results instead."
                }
            }
            let localResults = SearchService.search(query: query, in: appState.allFiles(), aiFilters: filters)
            await MainActor.run {
                results = localResults
                isSearching = false
            }
        }
    }
}
