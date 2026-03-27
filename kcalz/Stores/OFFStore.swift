import Foundation
import GRDB

/// Errors specific to the OpenFoodFacts database store.
enum OFFStoreError: LocalizedError {
    case databaseNotFound

    var errorDescription: String? {
        switch self {
        case .databaseNotFound: "off_fr.sqlite introuvable dans le bundle"
        }
    }
}

/// Read-only store for OpenFoodFacts product database (off_fr.sqlite).
final class OFFStore: Sendable {
    private static let minQueryLength = 2
    private static let searchResultLimit = 50

    private let dbQueue: DatabaseQueue

    /// Opens the bundled OFF database in read-only mode.
    init() throws {
        guard let path = Bundle.main.path(forResource: "off_fr", ofType: "sqlite") else {
            throw OFFStoreError.databaseNotFound
        }
        var config = Configuration()
        config.readonly = true
        dbQueue = try DatabaseQueue(path: path, configuration: config)
    }

    /// Looks up a product by its EAN barcode code. Returns nil if not found.
    func findByBarcode(_ code: String) -> OFFProduct? {
        try? dbQueue.read { db in
            try OFFProduct.fetchOne(db, sql: "SELECT * FROM products WHERE code = ?", arguments: [code])
        }
    }

    /// Full-text searches products by name tokens, ordered by popularity (scans).
    func search(query: String) throws -> [OFFProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minQueryLength else { return [] }

        // FTS5 tokenization: keep only alphanumeric chars to avoid FTS5 syntax errors.
        // Only the last token gets prefix wildcard (*) — earlier tokens are complete words
        // and match exactly, which avoids "cuit"* matching "cuisiné", "cuisine", etc.
        let cleaned = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .compactMap { token -> String? in
                let c = token.filter { $0.isLetter || $0.isNumber }
                return c.isEmpty ? nil : c
            }
        guard !cleaned.isEmpty else { return [] }
        // FTS query targets name column only — avoids false matches from brands/categories
        // (e.g. "Poulet au curry" matching "riz cuit" via category "Plats cuisinés au riz").
        let tokens = cleaned.enumerated().map { i, c in
            i == cleaned.count - 1 ? "name:\"\(c)\"*" : "name:\"\(c)\""
        }
        let ftsQuery = tokens.joined(separator: " ")

        return try dbQueue.read { db in
            // Ranking: kcal exists → shorter name → popularity
            let sql = """
                SELECT p.*
                FROM products p
                JOIN products_fts fts ON fts.rowid = p.rowid
                WHERE products_fts MATCH ?
                ORDER BY (CASE WHEN p.kcal IS NOT NULL THEN 0 ELSE 1 END),
                         LENGTH(p.name),
                         COALESCE(p.scans, 0) DESC
                LIMIT \(Self.searchResultLimit)
                """
            return try OFFProduct.fetchAll(db, sql: sql, arguments: [ftsQuery])
        }
    }
}
