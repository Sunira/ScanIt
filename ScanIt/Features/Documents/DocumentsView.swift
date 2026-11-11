import PhotosUI
import SwiftData
import SwiftUI

/// The Documents tab: the library list with category filters, importing, and the Scan button.
struct DocumentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.createdAt, order: .reverse) private var documents: [Document]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var selectedCategoryKey: String?
    @State private var path: [Document] = []
    @State private var showingScanner = false
    @State private var showingScannerUnavailable = false
    @State private var showingPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showingFileImporter = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var store: DocumentStore { DocumentStore(context: modelContext) }
    private var filteredDocuments: [Document] {
        DocumentFilter.apply(documents, categoryKey: selectedCategoryKey)
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Color(.systemGroupedBackground))
                .safeAreaInset(edge: .top, spacing: 0) { filterBar }
                .navigationTitle("Documents")
                .navigationDestination(for: Document.self) { DocumentDetailView(document: $0) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { importMenu }
                }
                .overlay(alignment: .bottomTrailing) {
                    ScanButton(action: startScan)
                        .padding(Metrics.screenPadding)
                }
                .overlay {
                    if isSaving { SavingOverlay() }
                }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView { outcome in
                showingScanner = false
                handleScan(outcome)
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItems,
                      maxSelectionCount: 20, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            importPhotos(items)
            photoItems = []
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image],
                      allowsMultipleSelection: true) { result in
            importFiles(result)
        }
        .alert("Scanning needs a camera", isPresented: $showingScannerUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The document scanner works on a real iPhone. You can still import from Photos or Files.")
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if documents.isEmpty {
            ContentUnavailableView {
                Label("No documents yet", systemImage: "doc.viewfinder")
            } description: {
                Text("Tap the scan button to scan your first document, or import from Photos or Files.")
            }
        } else if filteredDocuments.isEmpty {
            ContentUnavailableView("Nothing in this category yet",
                                   systemImage: "line.3.horizontal.decrease.circle")
        } else {
            List {
                ForEach(filteredDocuments) { document in
                    NavigationLink(value: document) {
                        DocumentRow(document: document)
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.delete(document)
                        }
                    }
                }
            }
            .contentMargins(.bottom, Metrics.scanButtonSize + 24, for: .scrollContent)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedCategoryKey == nil) {
                    selectedCategoryKey = nil
                }
                ForEach(categories) { category in
                    FilterChip(title: category.name, isSelected: selectedCategoryKey == category.key) {
                        selectedCategoryKey = category.key
                    }
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.vertical, 8)
        }
    }

    private var importMenu: some View {
        Menu {
            Button("Choose from Photos", systemImage: "photo.on.rectangle") { showingPhotoPicker = true }
            Button("Choose from Files", systemImage: "folder") { showingFileImporter = true }
        } label: {
            Label("Import", systemImage: "square.and.arrow.down")
        }
    }

    // MARK: Actions

    private func startScan() {
        if DocumentScannerView.isSupported {
            showingScanner = true
        } else {
            showingScannerUnavailable = true
        }
    }

    private func handleScan(_ outcome: ScanOutcome) {
        switch outcome {
        case .finished(let images):
            save { [try await store.createDocument(images: images, source: .camera)] }
        case .cancelled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        save {
            var datas: [Data] = []
            for item in items {
                if let data = try await item.loadTransferable(type: Data.self) {
                    datas.append(data)
                }
            }
            return try await store.importImages(datas, source: .photos)
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            save {
                var documents: [Document] = []
                for url in urls {
                    documents.append(try await store.importFile(at: url))
                }
                return documents
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    /// Runs a save with the "Saving…" overlay, then opens the document if there's exactly one.
    private func save(_ work: @escaping @MainActor () async throws -> [Document]) {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let saved = try await work()
                selectedCategoryKey = nil
                if saved.count == 1, let document = saved.first {
                    path.append(document)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// One row in the Documents list.
struct DocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(data: document.thumbnailData)
                .frame(width: 44, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let category = document.category {
                        CategoryTag(category: category.style)
                    } else {
                        StatusTag(text: "Not sorted yet")
                    }
                    Text(document.createdAt, format: .dateTime.month(.abbreviated).day())
                    Text(document.pageCount == 1 ? "1 page" : "\(document.pageCount) pages")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A grey label for documents the AI hasn't sorted yet.
struct StatusTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 6))
    }
}

/// A small page preview with a thin border.
struct ThumbnailView: View {
    let data: Data?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc")
                    .foregroundStyle(.tertiary)
            }
        }
        .clipShape(.rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separator), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

/// Shown while a scan or import is being saved.
struct SavingOverlay: View {
    var body: some View {
        ProgressView("Saving…")
            .padding(24)
            .background(.regularMaterial, in: .rect(cornerRadius: Metrics.cornerRadius))
    }
}

#Preview {
    DocumentsView()
        .modelContainer(try! AppSchema.makeContainer(inMemory: true))
}
