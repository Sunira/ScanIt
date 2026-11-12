import Foundation
import Testing
@testable import ScanIt

struct SearchIndexTests {
    let index: SearchIndex

    init() throws {
        index = try SearchIndex()
    }

    @Test func findsAWordInTheBody() throws {
        let water = UUID(), power = UUID()
        try index.upsert(documentID: water, title: "Water bill", tags: [], body: "Amount due $42.10 by March 3")
        try index.upsert(documentID: power, title: "Power bill", tags: [], body: "Amount due $88.00")

        let hits = try index.search("march")

        #expect(hits.map(\.documentID) == [water])
        #expect(hits[0].snippet.contains(SearchIndex.matchStart + "March" + SearchIndex.matchEnd))
    }

    @Test func requiresEveryWord() throws {
        let id = UUID()
        try index.upsert(documentID: id, title: "Dentist", tags: [], body: "Cleaning and checkup")

        #expect(try index.search("cleaning checkup").count == 1)
        #expect(try index.search("cleaning surgery").isEmpty)
    }

    @Test func matchesWordPrefixes() throws {
        let id = UUID()
        try index.upsert(documentID: id, title: "Receipt", tags: [], body: "Payments received")

        #expect(try index.search("pay").count == 1)
        #expect(try index.search("payments").count == 1)
    }

    @Test func searchesTitlesAndTags() throws {
        let id = UUID()
        try index.upsert(documentID: id, title: "Hospital invoice", tags: ["surgery", "2026"], body: "")

        #expect(try index.search("hospital").count == 1)
        #expect(try index.search("surgery").count == 1)
    }

    @Test func ignoresAccentsAndCase() throws {
        let id = UUID()
        try index.upsert(documentID: id, title: "Café", tags: [], body: "")

        #expect(try index.search("CAFE").count == 1)
    }

    @Test func punctuationInAQueryIsHarmless() throws {
        try index.upsert(documentID: UUID(), title: "Note", tags: [], body: "hello world")

        #expect(try index.search("\"hello\" (world*").count == 1)
        #expect(try index.search("   ").isEmpty)
        #expect(try index.search("***").isEmpty)
    }

    @Test func upsertReplacesAndRemoveDeletes() throws {
        let id = UUID()
        try index.upsert(documentID: id, title: "Old", tags: [], body: "alpha")
        try index.upsert(documentID: id, title: "New", tags: [], body: "beta")

        #expect(try index.search("alpha").isEmpty)
        #expect(try index.search("beta").count == 1)
        #expect(try index.indexedIDs() == [id])

        try index.remove(documentID: id)
        #expect(try index.search("beta").isEmpty)
    }

    @Test func snippetIsStyledWithMatchesInBold() {
        let text = SearchSnippet.attributed("Due \(SearchIndex.matchStart)March\(SearchIndex.matchEnd) 3")
        #expect(String(text.characters) == "Due March 3")
    }
}
