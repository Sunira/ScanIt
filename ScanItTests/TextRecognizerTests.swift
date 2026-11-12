import SwiftData
import Testing
import UIKit
@testable import ScanIt

@MainActor
struct TextRecognizerTests {
    private func page(_ text: String) -> Data {
        let size = CGSize(width: 1200, height: 600)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(in: CGRect(x: 60, y: 200, width: 1080, height: 200),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 90, weight: .bold),
                                                     .foregroundColor: UIColor.black])
        }
        return image.jpegData(compressionQuality: 0.9)!
    }

    @Test func readsPrintedText() async {
        let text = await TextRecognizer.recognizeText(in: [page("Invoice Total 42")])
        #expect(text.localizedCaseInsensitiveContains("invoice"))
    }

    @Test func blankPageGivesNoText() async {
        let blank = TestImages.solid(.white, size: CGSize(width: 600, height: 800)).jpegData(compressionQuality: 0.9)!
        let text = await TextRecognizer.recognizeText(in: [blank])
        #expect(text.isEmpty)
    }

    @Test func newDocumentBecomesSearchable() async throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let index = try SearchIndex()
        let indexer = TextIndexer(index: index)
        let store = DocumentStore(context: container.mainContext, indexer: indexer)
        let image = UIImage(data: page("Dentist Receipt"))!

        let document = try await store.createDocument(images: [image], source: .camera)
        await indexer.recognizeAndIndex(document)

        #expect(document.ocrText?.localizedCaseInsensitiveContains("dentist") == true)
        #expect(try index.search("dentist").map(\.documentID) == [document.id])

        store.delete(document)
        #expect(try index.search("dentist").isEmpty)
    }

    @Test func catchUpReadsOldDocumentsAndDropsDeletedOnes() async throws {
        let container = try AppSchema.makeContainer(inMemory: true)
        let index = try SearchIndex()
        let indexer = TextIndexer(index: index)
        let store = DocumentStore(context: container.mainContext)
        let document = try await store.createDocument(images: [UIImage(data: page("Library Card"))!], source: .photos)
        try index.upsert(documentID: UUID(), title: "Ghost", tags: [], body: "ghost")

        await indexer.catchUp(context: container.mainContext)

        #expect(try index.search("library").map(\.documentID) == [document.id])
        #expect(try index.search("ghost").isEmpty)
    }
}
