import Foundation
import GRDB

enum UserStoreError: LocalizedError {
    case directoryCreationFailed

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed: "Impossible de créer le dossier de données"
        }
    }
}

final class UserStore: Sendable {
    private let dbQueue: DatabaseQueue

    init() throws {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbURL = appSupport.appendingPathComponent("user.sqlite")

        dbQueue = try DatabaseQueue(path: dbURL.path)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "food_entry") { t in
                t.primaryKey("id", .text)
                t.column("date", .text).notNull()
                t.column("meal_type", .text).notNull()
                t.column("name", .text).notNull()
                t.column("grams", .double).notNull()
                t.column("kcal_per_100g", .double).notNull()
                t.column("proteins_per_100g", .double).notNull()
                t.column("carbs_per_100g", .double).notNull()
                t.column("fat_per_100g", .double).notNull()
                t.column("sugars_per_100g", .double)
                t.column("salt_per_100g", .double)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
            }
            try db.create(
                index: "idx_food_entry_date",
                on: "food_entry",
                columns: ["date"]
            )
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Read

    func loadDayLog(for date: Date) throws -> DayLog {
        let dateStr = date.kcDateString

        let entries = try dbQueue.read { db in
            let sql = """
                SELECT * FROM food_entry
                WHERE date = ?
                ORDER BY meal_type, sort_order
                """
            return try Row.fetchAll(db, sql: sql, arguments: [dateStr])
        }

        let grouped = Dictionary(grouping: entries) { row -> String in
            row["meal_type"] as? String ?? ""
        }

        let meals = MealType.allCases.map { mealType in
            let rows = grouped[mealType.rawValue] ?? []
            let foodEntries = rows.map { row -> FoodEntry in
                FoodEntry(
                    id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
                    name: row["name"] as? String ?? "",
                    grams: row["grams"] as? Double ?? 0,
                    kcalPer100g: row["kcal_per_100g"] as? Double ?? 0,
                    proteinsPer100g: row["proteins_per_100g"] as? Double ?? 0,
                    carbsPer100g: row["carbs_per_100g"] as? Double ?? 0,
                    fatPer100g: row["fat_per_100g"] as? Double ?? 0,
                    sugarsPer100g: row["sugars_per_100g"] as? Double,
                    saltPer100g: row["salt_per_100g"] as? Double,
                    sortOrder: row["sort_order"] as? Int ?? 0
                )
            }
            return Meal(type: mealType, entries: foodEntries)
        }

        return DayLog(date: date, meals: meals)
    }

    // MARK: - Write

    func addEntry(_ entry: FoodEntry, date: Date, mealType: MealType) throws {
        let dateStr = date.kcDateString

        let nextOrder = try dbQueue.read { db -> Int in
            let sql = "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM food_entry WHERE date = ? AND meal_type = ?"
            return try Int.fetchOne(db, sql: sql, arguments: [dateStr, mealType.rawValue]) ?? 0
        }

        try dbQueue.write { db in
            let sql = """
                INSERT INTO food_entry (id, date, meal_type, name, grams, kcal_per_100g, proteins_per_100g, carbs_per_100g, fat_per_100g, sugars_per_100g, salt_per_100g, sort_order)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
            try db.execute(sql: sql, arguments: [
                entry.id.uuidString,
                dateStr,
                mealType.rawValue,
                entry.name,
                entry.grams,
                entry.kcalPer100g,
                entry.proteinsPer100g,
                entry.carbsPer100g,
                entry.fatPer100g,
                entry.sugarsPer100g,
                entry.saltPer100g,
                nextOrder,
            ])
        }
    }

    func updateEntryGrams(id: UUID, grams: Double) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE food_entry SET grams = ? WHERE id = ?",
                arguments: [grams, id.uuidString]
            )
        }
    }

    func deleteEntry(id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM food_entry WHERE id = ?", arguments: [id.uuidString])
        }
    }
}
