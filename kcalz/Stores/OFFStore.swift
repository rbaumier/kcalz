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

        // FTS5 tokenization: keep only alphanumeric chars to avoid FTS5 syntax errors
        // (operators like -, +, OR are reserved). Wrap each token in quotes for literal
        // matching, append * for prefix search (e.g. "pomm"* matches "pommes").
        let tokens = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .compactMap { token -> String? in
                let cleaned = token.filter { $0.isLetter || $0.isNumber }
                guard !cleaned.isEmpty else { return nil }
                return "\"\(cleaned)\"*"
            }
        guard !tokens.isEmpty else { return [] }
        let ftsQuery = tokens.joined(separator: " ")

        return try dbQueue.read { db in
            let sql = """
                SELECT p.*
                FROM products p
                JOIN products_fts fts ON fts.rowid = p.rowid
                WHERE products_fts MATCH ?
                ORDER BY p.scans DESC
                LIMIT \(Self.searchResultLimit)
                """
            return try OFFProduct.fetchAll(db, sql: sql, arguments: [ftsQuery])
        }
    }
}
