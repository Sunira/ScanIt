import Foundation
import SwiftData
import Testing
import UIKit
@testable import ScanIt

@MainActor
struct DocumentStoreTests {
    let container: ModelContainer
    let store: DocumentStore

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
        store = DocumentStore(context: container.mainContext)
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<T>())
    }

    @Test func savesAScanWithPagesInOrder() async throws {
        let images = [TestImages.solid(.red, size: CGSize(width: 300, height: 400)),
                      TestImages.solid(.blue, size: CGSize(width: 300, height: 400))]

        let document = try await store.createDocument(images: images, source: .camera)

        #expect(document.sortedPages.map(\.index) == [0, 1])
        let everyPageHasImage = document.sortedPages.allSatisfy { $0.imageData != nil }
        #expect(everyPageHasImage)
        #expect(document.thumbnailData != nil)
        #expect(document.aiStatus == .pending)
        #expect(document.source == .camera)
        #expect(document.title.hasPrefix("Scan – "))
        #expect(try count(Document.self) == 1)
        #expect(try count(PageImage.self) == 2)
    }

    @Test func rejectsAnEmptyScan() async {
        await #expect(throws: ImportError.noPages) {
            try await store.createDocument(images: [], source: .camera)
        }
    }

    @Test func importsAMultiPagePDFAndKeepsTheOriginal() async throws {
        let pdf = TestImages.pdf(pages: 3)

        let document = try await store.importPDF(data: pdf, title: "Lease", source: .files)

        #expect(document.title == "Lease")
        #expect(document.pageCount == 3)
        #expect(document.originalPDF == pdf)
    }

    @Test func rejectsAnUnreadablePDF() async {
        await #expect(throws: ImportError.unreadablePDF("Broken")) {
            try await store.importPDF(data: Data("nope".utf8), title: "Broken", source: .files)
        }
    }

    @Test func importsEachPhotoAsItsOwnDocument() async throws {
        let photos = try [UIColor.red, .green].map { color in
            try #require(TestImages.solid(color, size: CGSize(width: 200, height: 200)).pngData())
        }

        let documents = try await store.importImages(photos, source: .photos)

        #expect(documents.count == 2)
        let allSinglePagePhotos = documents.allSatisfy { $0.pageCount == 1 && $0.source == .photos }
        #expect(allSinglePagePhotos)
    }

    @Test func importsAnImageFile() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "Receipt.png")
        try #require(TestImages.solid(.gray, size: CGSize(width: 100, height: 100)).pngData()).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await store.importFile(at: url)

        #expect(document.title == "Receipt")
        #expect(document.pageCount == 1)
    }

    @Test func deletingADocumentDeletesItsPages() async throws {
        let document = try await store.createDocument(
            images: [TestImages.solid(.red, size: CGSize(width: 100, height: 100))], source: .camera)

        store.delete(document)

        #expect(try count(Document.self) == 0)
        #expect(try count(PageImage.self) == 0)
    }

    @Test func seedsTheStarterCategoriesOnlyOnce() throws {
        store.seedCategoriesIfNeeded()
        store.seedCategoriesIfNeeded()

        let categories = try container.mainContext.fetch(FetchDescriptor<ScanIt.Category>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(categories.map(\.key) == StarterCategories.all.map(\.id))
        let allBuiltIn = categories.allSatisfy { $0.isBuiltIn }
        #expect(allBuiltIn)
    }

    @Test func filtersDocumentsByCategory() async throws {
        store.seedCategoriesIfNeeded()
        let bills = try #require(try container.mainContext.fetch(FetchDescriptor<ScanIt.Category>()).first { $0.key == "bills" })
        let image = TestImages.solid(.red, size: CGSize(width: 100, height: 100))
        let bill = try await store.createDocument(images: [image], source: .camera)
        let other = try await store.createDocument(images: [image], source: .camera)
        bill.category = bills

        #expect(DocumentFilter.apply([bill, other], categoryKey: "bills").map(\.id) == [bill.id])
        #expect(DocumentFilter.apply([bill, other], categoryKey: nil).count == 2)
    }
}

struct DocumentNamingTests {
    @Test func namesDocumentsBySourceAndDate() {
        let date = Date(timeIntervalSince1970: 1_794_412_920) // Nov 11, 2026
        let utc = TimeZone(identifier: "UTC")!
        let english = Locale(identifier: "en_US")

        let scan = DocumentNaming.defaultTitle(source: .camera, date: date, locale: english, timeZone: utc)
        let photo = DocumentNaming.defaultTitle(source: .photos, date: date, locale: english, timeZone: utc)

        #expect(scan.hasPrefix("Scan – Nov 11, 2026"))
        #expect(photo.hasPrefix("Photo – "))
    }
}
