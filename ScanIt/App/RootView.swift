import SwiftUI

/// The app's main tabs. On iPad and Mac (V3) this becomes a sidebar.
enum AppTab: Hashable {
    case documents, search, family, settings
}

struct RootView: View {
    @State private var selection: AppTab = .documents

    var body: some View {
        TabView(selection: $selection) {
            Tab("Documents", systemImage: "doc.text", value: AppTab.documents) {
                DocumentsView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                SearchView()
            }
            Tab("Family", systemImage: "person.2", value: AppTab.family) {
                FamilyComingSoonView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootView()
}
