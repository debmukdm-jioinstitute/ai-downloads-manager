import SwiftUI

struct RulesView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSuggestions = false
    @State private var suggestions: [OrganizeSuggestion] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Automation Rules").font(.title2.bold())
                Spacer()
                Button("Organize Downloads") { computeSuggestions() }
                    .buttonStyle(.borderedProminent)
            }

            List {
                let existingRules = appState.rules()
                if existingRules.isEmpty {
                    Text("No rules yet. Rules are created from 'Organize Downloads' suggestions, or a suggestion you apply automatically next time.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(existingRules) { rule in
                        VStack(alignment: .leading) {
                            Text(rule.name).bold()
                            Text("\(rule.matchCategory)\(rule.matchSubcategory.map { "/\($0)" } ?? "") → \(rule.destinationSubpath)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .navigationTitle("Rules")
        .sheet(isPresented: $showingSuggestions) {
            OrganizeSuggestionsSheet(suggestions: suggestions, isPresented: $showingSuggestions)
        }
    }

    private func computeSuggestions() {
        let files = appState.allFiles().filter { !$0.userApprovedClassification }
        let grouped = Dictionary(grouping: files) { file in
            "\(file.category)|\(file.subcategory ?? "")"
        }
        suggestions = grouped.compactMap { key, files -> OrganizeSuggestion? in
            guard !files.isEmpty else { return nil }
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            let category = parts.first ?? "Other"
            let subcategory = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
            return OrganizeSuggestion(category: category, subcategory: subcategory, files: files)
        }.sorted { $0.files.count > $1.files.count }
        showingSuggestions = true
    }
}

struct OrganizeSuggestion: Identifiable {
    var id: String { "\(category)|\(subcategory ?? "")" }
    let category: String
    let subcategory: String?
    let files: [FileRecord]
}

struct OrganizeSuggestionsSheet: View {
    @EnvironmentObject var appState: AppState
    let suggestions: [OrganizeSuggestion]
    @Binding var isPresented: Bool
    @State private var reviewing: OrganizeSuggestion?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Organization").font(.title3.bold())
            if suggestions.isEmpty {
                Text("Nothing to suggest — everything is already organized or approved.")
                    .foregroundStyle(.secondary)
            }
            List(suggestions) { suggestion in
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(suggestion.files.count) \(suggestion.category.lowercased())")
                        Text("→ \(suggestion.category)\(suggestion.subcategory.map { "/\($0)" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Review") { reviewing = suggestion }
                    Button("Apply") { apply(suggestion) }
                        .buttonStyle(.borderedProminent)
                }
            }
            HStack {
                Spacer()
                Button("Close") { isPresented = false }
            }
        }
        .padding(20)
        .frame(width: 520, height: 420)
        .sheet(item: $reviewing) { suggestion in
            VStack(alignment: .leading, spacing: 8) {
                Text("Files to move to \(suggestion.category)\(suggestion.subcategory.map { "/\($0)" } ?? "")").bold()
                List(suggestion.files) { file in Text(file.filename) }
                Button("Close") { reviewing = nil }
            }
            .padding(20)
            .frame(width: 420, height: 380)
        }
    }

    private func apply(_ suggestion: OrganizeSuggestion) {
        guard let organizer = appState.organizer() else { return }
        for file in suggestion.files {
            try? organizer.moveToCategory(file, category: suggestion.category, subcategory: suggestion.subcategory)
        }
    }
}
