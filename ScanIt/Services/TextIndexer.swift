import Foundation
import SwiftData

/// Reads the text of new documents and keeps the search index in step with the library.
@MainActor
final class TextIndexer {
    static let shared = TextIndexer(index: SearchIndex.shared)

    let index: SearchIndex?
    private var inFlight: Set<UUID> = []

    init(index: SearchIndex?) {
        self.index = index
    }

    /// Reads the document's pages (once) and adds it to the search index.
    func recognizeAndIndex(_ document: Document) async {
        let id = document.id
        guard document.ocrText == nil, inFlight.insert(id).inserted else {
            reindex(document)
            return
        }
        defer { inFlight.remove(id) }

        let pages = document.sortedPages.compactMap(\.imageData)
        let text = await TextRecognizer.recognizeText(in: pages)
        guard !document.isDeleted else { return }
        document.ocrText = text
        try? document.modelContext?.save()
        reindex(document)
    }

    /// Updates the index entry after the title, tags or text changed.
    func reindex(_ document: Document) {
        try? index?.upsert(documentID: document.id, title: document.title,
                           tags: document.tags, body: document.ocrText ?? "")
    }

    func remove(documentID: UUID) {
        try? index?.remove(documentID: documentID)
    }

    /// Catches up after an update or a sync: reads documents that haven't been read yet,
    /// adds anything missing from the index, and drops entries for deleted documents.
    func catchUp(context: ModelContext) async {
        guard let index else { return }
        let documents = (try? context.fetch(FetchDescriptor<Document>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let indexed = (try? index.indexedIDs()) ?? []

        for stale in indexed.subtracting(documents.map(\.id)) {
            remove(documentID: stale)
        }
        for document in documents {
            if document.ocrText == nil {
                await recognizeAndIndex(document)
            } else if !indexed.contains(document.id) {
                reindex(document)
            }
        }
    }
}
