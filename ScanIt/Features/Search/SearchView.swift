import SwiftUI

/// The Search tab, with separate Search and Ask modes.
/// Keyword search arrives in M2; Ask arrives in V2.
struct SearchView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case search = "Search"
        case ask = "Ask"
        var id: Self { self }
    }

    @State private var mode: Mode = .search
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 8)

                switch mode {
                case .search:
                    searchContent
                case .ask:
                    ContentUnavailableView {
                        Label("Ask is coming in V2", systemImage: "bubble.left.and.text.bubble.right")
                    } description: {
                        Text("Soon you'll be able to ask questions like \u{201C}How much did we spend at the dentist this year?\u{201D}")
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        VStack {
            TextField("Search every word…", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, Metrics.screenPadding)
            if query.isEmpty {
                ContentUnavailableView {
                    Label("Search your documents", systemImage: "magnifyingglass")
                } description: {
                    Text("Search will look through every word of your scans.")
                }
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}

#Preview {
    SearchView()
}
