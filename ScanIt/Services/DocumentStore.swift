import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

enum ImportError: LocalizedError, Equatable {
    case noPages
    case unreadableFile(String)
    case unreadablePDF(String)

    var errorDescription: String? {
        switch self {
        case .noPages:
            "The scan didn't contain any pages."
        case .unreadableFile(let name):
            "\u{201C}\(name)\u{201D} couldn't be opened as an image or PDF."
        case .unreadablePDF(let name):
            "\u{201C}\(name)\u{201D} couldn't be read as a PDF."
        }
    }
}

enum DocumentNaming {
    /// The title a document gets before the AI suggests a better one, e.g. "Scan – Nov 11, 2026 at 3:42 PM".
    static func defaultTitle(source: DocumentSource, date: Date,
                             locale: Locale = .autoupdatingCurrent,
                             timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let prefix = switch source {
        case .camera: "Scan"
        case .photos: "Photo"
        case .files: "File"
        case .share: "Shared"
        }
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, timeZone: timeZone)
        return "\(prefix) – \(date.formatted(style))"
    }
}

enum DocumentFilter {
    /// Documents in the chosen category, or all of them when `categoryKey` is nil.
    static func apply(_ documents: [Document], categoryKey: String?) -> [Document] {
        guard let categoryKey else { return documents }
        return documents.filter { $0.category?.key == categoryKey }
    }
}

/// Creates, imports and deletes documents.
@MainActor
final class DocumentStore {
    let context: ModelContext
    /// Reads and indexes the text of new documents. Nil in tests that don't need it.
    let indexer: TextIndexer?

    init(context: ModelContext, indexer: TextIndexer? = nil) {
        self.context = context
        self.indexer = indexer
    }

    // MARK: Creating

    /// Saves a new document from page images. Images are compressed off the main thread.
    @discardableResult
    func createDocument(images: [UIImage], source: DocumentSource, title: String? = nil,
                        originalPDF: Data? = nil, date: Date = .now) async throws -> Document {
        guard !images.isEmpty else { throw ImportError.noPages }

        let encoded = await Task.detached(priority: .userInitiated) {
            (pages: images.compactMap(ImageProcessing.encodePage),
             thumbnail: images.first.flatMap(ImageProcessing.thumbnail))
        }.value
        guard !encoded.pages.isEmpty else { throw ImportError.noPages }

        let document = Document(title: title ?? DocumentNaming.defaultTitle(source: source, date: date),
                                source: source, createdAt: date)
        document.thumbnailData = encoded.thumbnail
        document.originalPDF = originalPDF
        context.insert(document)
        document.pages = encoded.pages.enumerated().map { PageImage(index: $0.offset, imageData: $0.element) }
        try context.save()
        if let indexer {
            Task { await indexer.recognizeAndIndex(document) }
        }
        return document
    }

    /// Imports a PDF, keeping the original file alongside page images.
    @discardableResult
    func importPDF(data: Data, title: String?, source: DocumentSource) async throws -> Document {
        let images = await Task.detached(priority: .userInitiated) {
            PDFRendering.renderPages(from: data)
        }.value
        guard let images, !images.isEmpty else { throw ImportError.unreadablePDF(title ?? "PDF") }
        return try await createDocument(images: images, source: source, title: title, originalPDF: data)
    }

    /// Imports images (e.g. from Photos). Each image becomes its own document.
    @discardableResult
    func importImages(_ items: [Data], source: DocumentSource) async throws -> [Document] {
        var documents: [Document] = []
        for data in items {
            guard let image = UIImage(data: data) else { throw ImportError.unreadableFile("Image") }
            documents.append(try await createDocument(images: [image], source: source))
        }
        return documents
    }

    /// Imports a PDF or image picked in the Files app.
    @discardableResult
    func importFile(at url: URL, source: DocumentSource = .files) async throws -> Document {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let name = url.deletingPathExtension().lastPathComponent
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
            return try await importPDF(data: data, title: name, source: source)
        }
        guard let image = UIImage(data: data) else { throw ImportError.unreadableFile(url.lastPathComponent) }
        return try await createDocument(images: [image], source: source, title: name)
    }

    // MARK: Deleting

    func delete(_ document: Document) {
        indexer?.remove(documentID: document.id)
        context.delete(document)
        try? context.save()
    }

    // MARK: Categories

    /// Adds the starter categories the first time the app runs.
    func seedCategoriesIfNeeded() {
        let existing = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard existing == 0 else { return }
        for (order, style) in StarterCategories.all.enumerated() {
            context.insert(Category(key: style.id, name: style.name, symbol: style.symbol,
                                    paletteKey: style.id, sortOrder: order, isBuiltIn: true))
        }
        try? context.save()
    }
}
