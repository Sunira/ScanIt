import Foundation
import SwiftData

/// Whether a scan is a paper document or a regular photo. Decided by the AI in M3.
enum DocumentKind: String, Codable, CaseIterable, Sendable {
    case document, photo
}

/// Where a document came from.
enum DocumentSource: String, Codable, CaseIterable, Sendable {
    case camera, photos, files, share
}

/// Progress of AI reading and sorting (M3).
enum AIStatus: String, Codable, CaseIterable, Sendable {
    case pending, processing, done, failed
}

// CloudKit sync (M7) needs every stored property to be optional or have a default,
// relationships to be optional, and no unique constraints. Keep it that way.

@Model
final class Document {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var title: String = ""
    var summary: String?
    var tags: [String] = []
    var ocrText: String?
    var kindRaw: String = DocumentKind.document.rawValue
    var sourceRaw: String = DocumentSource.camera.rawValue
    var aiStatusRaw: String = AIStatus.pending.rawValue

    var category: Category?

    @Relationship(deleteRule: .cascade, inverse: \PageImage.document)
    var pages: [PageImage]? = []

    /// The original file when a PDF was imported, kept for export in M6.
    @Attribute(.externalStorage) var originalPDF: Data?
    /// A small JPEG of the first page for the Documents list.
    @Attribute(.externalStorage) var thumbnailData: Data?

    init(title: String, source: DocumentSource, createdAt: Date = .now) {
        self.title = title
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
    }

    var kind: DocumentKind {
        get { DocumentKind(rawValue: kindRaw) ?? .document }
        set { kindRaw = newValue.rawValue }
    }

    var source: DocumentSource {
        get { DocumentSource(rawValue: sourceRaw) ?? .camera }
        set { sourceRaw = newValue.rawValue }
    }

    var aiStatus: AIStatus {
        get { AIStatus(rawValue: aiStatusRaw) ?? .pending }
        set { aiStatusRaw = newValue.rawValue }
    }

    /// Pages in reading order.
    var sortedPages: [PageImage] {
        (pages ?? []).sorted { $0.index < $1.index }
    }

    var pageCount: Int { pages?.count ?? 0 }
}

@Model
final class PageImage {
    var index: Int = 0
    /// The page image (HEIC, or JPEG as a fallback), stored outside the database file.
    @Attribute(.externalStorage) var imageData: Data?
    var document: Document?

    init(index: Int, imageData: Data?) {
        self.index = index
        self.imageData = imageData
    }
}

@Model
final class Category {
    /// Stable identifier, e.g. "bills". Built-in keys match `StarterCategories`.
    var key: String = ""
    var name: String = ""
    var symbol: String = "folder"
    /// Which color pair to use (a `StarterCategories` id).
    var paletteKey: String = "bills"
    var sortOrder: Int = 0
    var isBuiltIn: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Document.category)
    var documents: [Document]? = []

    init(key: String, name: String, symbol: String, paletteKey: String, sortOrder: Int, isBuiltIn: Bool) {
        self.key = key
        self.name = name
        self.symbol = symbol
        self.paletteKey = paletteKey
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
    }

    /// How this category looks in the interface.
    var style: CategoryStyle {
        let palette = StarterCategories.all.first { $0.id == paletteKey } ?? StarterCategories.all[0]
        return CategoryStyle(id: key, name: name, symbol: symbol,
                             foreground: palette.foreground, background: palette.background)
    }
}

enum AppSchema {
    static let schema = Schema([Document.self, PageImage.self, Category.self])

    /// The app's database. iCloud sync is switched on in M7.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema,
                                               isStoredInMemoryOnly: inMemory,
                                               cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
