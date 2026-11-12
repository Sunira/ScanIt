import SwiftData
import SwiftUI

/// The Search tab, with separate Search and Ask modes.
/// Keyword search arrives in M2; Ask arrives in V2.
struct SearchView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case search = "Search"
        case ask = "Ask"
        var id: Self { self }
    }

    @Query private var documents: [Document]

    @State private var mode: Mode = .search
    @State private var query = ""
    @State private var results: [Result] = []

    struct Result: Identifiable {
        let document: Document
        let snippet: AttributedString
        var id: UUID { document.id }
    }

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
            .navigationDestination(for: Document.self) { DocumentDetailView(document: $0) }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        VStack(spacing: 8) {
            TextField("Search every word…", text: $query)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .padding(.horizontal, Metrics.screenPadding)
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView {
                    Label("Search your documents", systemImage: "magnifyingglass")
                } description: {
                    Text("Find any word in any scan, even without internet.")
                }
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(results) { result in
                    NavigationLink(value: result.document) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.document.title).font(.headline).lineLimit(1)
                            Text(result.snippet)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .task(id: query) { runSearch() }
        .onChange(of: documents.count) { runSearch() }
    }

    private func runSearch() {
        guard let index = SearchIndex.shared,
              let hits = try? index.search(query) else {
            results = []
            return
        }
        let byID = Dictionary(documents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        results = hits.compactMap { hit in
            byID[hit.documentID].map { Result(document: $0, snippet: SearchSnippet.attributed(hit.snippet)) }
        }
    }
}

enum SearchSnippet {
    /// Turns an index snippet into styled text with the matched words in bold.
    static func attributed(_ snippet: String) -> AttributedString {
        var result = AttributedString()
        var highlighted = false
        let text = snippet.replacingOccurrences(of: "\n", with: " ")
        var buffer = ""
        func flush() {
            guard !buffer.isEmpty else { return }
            var piece = AttributedString(buffer)
            if highlighted {
                piece.font = .subheadline.bold()
                piece.foregroundColor = .primary
            }
            result += piece
            buffer = ""
        }
        for character in text {
            if String(character) == SearchIndex.matchStart {
                flush(); highlighted = true
            } else if String(character) == SearchIndex.matchEnd {
                flush(); highlighted = false
            } else {
                buffer.append(character)
            }
        }
        flush()
        return result
    }
}

#Preview {
    SearchView()
}
