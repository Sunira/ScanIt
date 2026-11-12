import Foundation
import GRDB

/// A document found by a keyword search.
struct SearchHit: Equatable, Sendable {
    let documentID: UUID
    /// A short excerpt with matches wrapped in `SearchIndex.matchStart` / `matchEnd` markers.
    let snippet: String
}

/// A full-text index (SQLite FTS5) of every document's title, tags and text.
/// It lives on the device and is rebuilt from the documents, so it never needs to sync.
final class SearchIndex: Sendable {
    static let matchStart = "\u{1}"
    static let matchEnd = "\u{2}"

    private let database: DatabaseQueue

    /// Opens (or creates) the index at `url`, or an in-memory index when `url` is nil.
    init(url: URL? = nil) throws {
        if let url {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            database = try DatabaseQueue(path: url.path)
        } else {
            database = try DatabaseQueue()
        }
        try database.write { db in
            try db.create(virtualTable: "documentText", ifNotExists: true, using: FTS5()) { table in
                table.tokenizer = .unicode61()
                table.column("documentID").notIndexed()
                table.column("title")
                table.column("tags")
                table.column("body")
            }
        }
    }

    static let shared: SearchIndex? = {
        let support = URL.applicationSupportDirectory.appending(path: "Search", directoryHint: .isDirectory)
        return try? SearchIndex(url: support.appending(path: "index.sqlite"))
    }()

    // MARK: Writing

    func upsert(documentID: UUID, title: String, tags: [String], body: String) throws {
        let id = documentID.uuidString
        try database.write { db in
            try db.execute(sql: "DELETE FROM documentText WHERE documentID = ?", arguments: [id])
            try db.execute(sql: "INSERT INTO documentText (documentID, title, tags, body) VALUES (?, ?, ?, ?)",
                           arguments: [id, title, tags.joined(separator: " "), body])
        }
    }

    func remove(documentID: UUID) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM documentText WHERE documentID = ?", arguments: [documentID.uuidString])
        }
    }

    func removeAll() throws {
        try database.write { db in try db.execute(sql: "DELETE FROM documentText") }
    }

    // MARK: Reading

    func indexedIDs() throws -> Set<UUID> {
        try database.read { db in
            Set(try String.fetchAll(db, sql: "SELECT documentID FROM documentText").compactMap(UUID.init))
        }
    }

    /// Documents containing every word of `query` (each word also matches as a prefix),
    /// best matches first.
    func search(_ query: String, limit: Int = 100) throws -> [SearchHit] {
        guard let pattern = Self.pattern(for: query) else { return [] }
        return try database.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT documentID,
                       snippet(documentText, -1, ?, ?, '…', 14) AS snippet
                FROM documentText
                WHERE documentText MATCH ?
                ORDER BY bm25(documentText, 0, 5, 3, 1)
                LIMIT ?
                """, arguments: [Self.matchStart, Self.matchEnd, pattern, limit])
            return rows.compactMap { row in
                guard let id = UUID(uuidString: row["documentID"]) else { return nil }
                return SearchHit(documentID: id, snippet: row["snippet"])
            }
        }
    }

    /// An FTS5 query from what the user typed. Punctuation is ignored so it can't break the query.
    static func pattern(for query: String) -> String? {
        let words = query.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !words.isEmpty else { return nil }
        return words.map { "\"\($0)\"*" }.joined(separator: " ")
    }
}
