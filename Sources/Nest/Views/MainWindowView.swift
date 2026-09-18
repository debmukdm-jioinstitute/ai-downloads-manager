import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case allFiles = "All Files"
    case categories = "Categories"
    case expiryCenter = "Expiry Center"
    case search = "Search"
    case rules = "Rules"
    case activity = "Activity"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .allFiles: return "doc.on.doc"
        case .categories: return "folder"
        case .expiryCenter: return "clock.badge.exclamationmark"
        case .search: return "magnifyingglass"
        case .rules: return "wand.and.stars"
        case .activity: return "clock"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFile: FileRecord?

    private var selection: Binding<SidebarSection?> {
        Binding(
            get: { appState.selectedSidebarSection },
            set: { appState.selectedSidebarSection = $0 ?? .overview }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } content: {
            switch appState.selectedSidebarSection {
            case .overview:
                OverviewView(selectedFile: $selectedFile)
            case .allFiles:
                AllFilesView(selectedFile: $selectedFile)
            case .categories:
                CategoriesView(selectedFile: $selectedFile)
            case .expiryCenter:
                ExpiryCenterView()
            case .search:
                SearchView(selectedFile: $selectedFile)
            case .rules:
                RulesView()
            case .activity:
                ActivityView()
            case .settings:
                SettingsView()
            }
        } detail: {
            if let selectedFile {
                FilePreviewPane(file: selectedFile)
            } else {
                ContentUnavailableView("No File Selected", systemImage: "doc", description: Text("Select a file to see details."))
            }
        }
    }
}
