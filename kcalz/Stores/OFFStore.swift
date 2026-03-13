import Foundation
import GRDB

enum OFFStoreError: LocalizedError {
    case databaseNotFound

    var errorDescription: String? {
        switch self {
        case .databaseNotFound: "off_fr.sqlite introuvable dans le bundle"
        }
    }
}

final class OFFStore: Sendable {
    private let dbQueue: DatabaseQueue

    init() throws {
        guard let path = Bundle.main.path(forResource: "off_fr", ofType: "sqlite") else {
            throw OFFStoreError.databaseNotFound
        }
        var config = Configuration()
        config.readonly = true
        dbQueue = try DatabaseQueue(path: path, configuration: config)
    }

    func search(query: String) throws -> [OFFProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let tokens = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { "\"\($0.replacingOccurrences(of: "\"", with: ""))\"*" }
        let ftsQuery = tokens.joined(separator: " ")

        return try dbQueue.read { db in
            let sql = """
                SELECT p.*
                FROM products p
                JOIN products_fts fts ON fts.rowid = p.rowid
                WHERE products_fts MATCH ?
                ORDER BY p.scans DESC
                LIMIT 50
                """
            return try OFFProduct.fetchAll(db, sql: sql, arguments: [ftsQuery])
        }
    }
}
