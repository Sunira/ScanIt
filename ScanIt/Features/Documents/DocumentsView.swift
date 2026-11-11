import SwiftUI

/// The Documents tab: the library list with category filters and the Scan button.
/// M0 shows the empty state; real documents arrive in M1.
struct DocumentsView: View {
    @State private var selectedCategoryID: String?
    @State private var showingScanInfo = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                ContentUnavailableView {
                    Label("No documents yet", systemImage: "doc.viewfinder")
                } description: {
                    Text("Tap the scan button to scan your first document.")
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Sort and view options", systemImage: "line.3.horizontal.decrease") {}
                        .disabled(true)
                    Button("Import from Photos or Files", systemImage: "square.and.arrow.down") {}
                        .disabled(true)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                ScanButton { showingScanInfo = true }
                    .padding(Metrics.screenPadding)
            }
            .alert("Scanning is coming next", isPresented: $showingScanInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The document scanner arrives in the next update (M1).")
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedCategoryID == nil) {
                    selectedCategoryID = nil
                }
                ForEach(StarterCategories.all) { category in
                    FilterChip(title: category.name, isSelected: selectedCategoryID == category.id) {
                        selectedCategoryID = category.id
                    }
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.vertical, 8)
        }
    }
}

/// The floating teal camera button that starts a scan.
struct ScanButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "viewfinder")
                .font(.system(size: 26, weight: .semibold))
                .frame(width: Metrics.scanButtonSize, height: Metrics.scanButtonSize)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Scan a document")
    }
}

#Preview {
    DocumentsView()
}
