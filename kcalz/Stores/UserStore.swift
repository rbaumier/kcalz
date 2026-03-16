import Foundation
import GRDB
import os

private let logger = Logger(subsystem: "com.kcalz", category: "UserStore")

/// Errors specific to the user database store.
enum UserStoreError: LocalizedError {
    case directoryCreationFailed

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed: "Impossible de créer le dossier de données"
        }
    }
}

/// Read-write store for user data (food log, goals, weight, custom foods).
final class UserStore: Sendable {
    private static let minQueryLength = 2
    private static let defaultHistoryLimit = 20
    private static let previousMealLookbackDays = 7
    private static let customCodePrefix = "custom:"
    private static let maxWeightEntries = 365

    private let dbQueue: DatabaseQueue

    /// Opens the user database in Application Support, seeding from the bundled copy on first launch.
    init() throws {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbURL = appSupport.appendingPathComponent("user.sqlite")

        // On first launch, copy the bundled seed database (pre-populated with MFP import data).
        if !fileManager.fileExists(atPath: dbURL.path),
           let bundled = Bundle.main.url(forResource: "user", withExtension: "sqlite") {
            try fileManager.copyItem(at: bundled, to: dbURL)
        }

        dbQueue = try DatabaseQueue(path: dbURL.path)
        try migrate()
    }

    /// Runs all incremental schema migrations.
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

        migrator.registerMigration("v2") { db in
            try db.create(table: "goals") { t in
                t.column("kcal", .double)
                t.column("proteins", .double)
                t.column("carbs", .double)
                t.column("fat", .double)
                t.column("sugars", .double)
                t.column("salt", .double)
            }
        }

        migrator.registerMigration("v3") { db in
            try db.create(table: "weight_entry") { t in
                t.primaryKey("date", .text)
                t.column("weight_kg", .double).notNull()
            }
        }

        migrator.registerMigration("v4") { db in
            try db.create(
                index: "idx_food_entry_name",
                on: "food_entry",
                columns: ["name"]
            )
        }

        migrator.registerMigration("v5") { db in
            try db.alter(table: "food_entry") { t in
                t.add(column: "brands", .text)
            }
        }

        migrator.registerMigration("v6") { db in
            try db.create(table: "product_override") { t in
                t.primaryKey("code", .text)
                t.column("kcal", .double).notNull()
                t.column("proteins", .double)
                t.column("carbs", .double)
                t.column("fat", .double)
                t.column("sugars", .double)
                t.column("salt", .double)
            }
        }

        migrator.registerMigration("v7") { db in
            try db.alter(table: "product_override") { t in
                t.add(column: "name", .text)
            }
            try db.alter(table: "product_override") { t in
                t.add(column: "brands", .text)
            }
        }

        migrator.registerMigration("v8") { db in
            try db.create(table: "weight_checkpoint") { t in
                t.primaryKey("id", .text)
                t.column("date", .text).notNull()
                t.column("weight_kg", .double).notNull()
                t.column("title", .text).notNull()
                t.column("goal", .text).notNull()
            }
        }

        migrator.registerMigration("v9") { db in
            try db.alter(table: "food_entry") { t in
                t.add(column: "fiber_per_100g", .double)
            }
            try db.alter(table: "product_override") { t in
                t.add(column: "fiber", .double)
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Goals

    /// Loads the single nutrition goal row, or returns defaults if none set.
    func loadGoals() throws -> NutritionGoal {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM goals LIMIT 1") else {
                return NutritionGoal()
            }
            return NutritionGoal(
                kcal: row["kcal"],
                proteins: row["proteins"],
                carbs: row["carbs"],
                fat: row["fat"],
                sugars: row["sugars"],
                salt: row["salt"]
            )
        }
    }

    /// Replaces the nutrition goal (single-row table, delete + insert).
    func saveGoals(_ goal: NutritionGoal) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM goals")
            try db.execute(
                sql: "INSERT INTO goals (kcal, proteins, carbs, fat, sugars, salt) VALUES (?, ?, ?, ?, ?, ?)",
                arguments: [goal.kcal, goal.proteins, goal.carbs, goal.fat, goal.sugars, goal.salt]
            )
        }
    }

    // MARK: - Read

    /// Loads all food entries for a given date, grouped into meals.
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
            let foodEntries = rows.map { Self.foodEntry(from: $0) }
            return Meal(type: mealType, entries: foodEntries)
        }

        return DayLog(date: date, meals: meals)
    }

    // MARK: - Write

    /// Adds a single food entry to a meal, appended at the end of the sort order.
    func addEntry(_ entry: FoodEntry, date: Date, mealType: MealType) throws {
        let dateStr = date.kcDateString

        try dbQueue.write { db in
            // COALESCE(MAX(sort_order), -1) + 1: use -1 as base so first entry gets sort_order 0
            let nextOrder: Int = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM food_entry WHERE date = ? AND meal_type = ?",
                arguments: [dateStr, mealType.rawValue]
            ) ?? 0

            let sql = """
                INSERT INTO food_entry (id, date, meal_type, name, brands, grams, kcal_per_100g, proteins_per_100g, carbs_per_100g, fat_per_100g, sugars_per_100g, salt_per_100g, fiber_per_100g, sort_order)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
            try db.execute(sql: sql, arguments: [
                entry.id.uuidString,
                dateStr,
                mealType.rawValue,
                entry.name,
                entry.brands,
                entry.grams,
                entry.kcalPer100g,
                entry.proteinsPer100g,
                entry.carbsPer100g,
                entry.fatPer100g,
                entry.sugarsPer100g,
                entry.saltPer100g,
                entry.fiberPer100g,
                nextOrder,
            ])
        }
    }

    /// Adds multiple food entries to a meal in a single transaction.
    func addEntries(_ entries: [FoodEntry], date: Date, mealType: MealType) throws {
        let dateStr = date.kcDateString
        try dbQueue.write { db in
            var nextOrder: Int = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM food_entry WHERE date = ? AND meal_type = ?", arguments: [dateStr, mealType.rawValue]) ?? 0
            for entry in entries {
                let sql = """
                    INSERT INTO food_entry (id, date, meal_type, name, brands, grams, kcal_per_100g, proteins_per_100g, carbs_per_100g, fat_per_100g, sugars_per_100g, salt_per_100g, fiber_per_100g, sort_order)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """
                try db.execute(sql: sql, arguments: [
                    entry.id.uuidString, dateStr, mealType.rawValue,
                    entry.name, entry.brands, entry.grams,
                    entry.kcalPer100g, entry.proteinsPer100g, entry.carbsPer100g,
                    entry.fatPer100g, entry.sugarsPer100g, entry.saltPer100g,
                    entry.fiberPer100g, nextOrder,
                ])
                nextOrder += 1
            }
        }
    }

    /// Updates the weight in grams for an existing food entry.
    func updateEntryGrams(id: UUID, grams: Double) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE food_entry SET grams = ? WHERE id = ?",
                arguments: [grams, id.uuidString]
            )
        }
    }

    /// Deletes a single food entry by ID.
    func deleteEntry(id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM food_entry WHERE id = ?", arguments: [id.uuidString])
        }
    }

    /// Deletes multiple food entries by their IDs in a single transaction.
    func deleteEntries(ids: Set<UUID>) throws {
        guard !ids.isEmpty else { return }
        try dbQueue.write { db in
            let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
            let sql = "DELETE FROM food_entry WHERE id IN (\(placeholders))"
            try db.execute(sql: sql, arguments: StatementArguments(ids.map { $0.uuidString }))
        }
    }

    // MARK: - Recents & Frequents

    /// Returns the most recently logged distinct foods.
    func recentFoods(limit: Int = defaultHistoryLimit) throws -> [FoodEntry] {
        try dbQueue.read { db in
            let sql = """
                SELECT *, MAX(rowid) as max_rowid FROM food_entry
                GROUP BY name
                ORDER BY max_rowid DESC
                LIMIT ?
                """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [limit])
            return rows.map { Self.foodEntry(from: $0) }
        }
    }

    /// Returns the most frequently logged distinct foods.
    func frequentFoods(limit: Int = defaultHistoryLimit) throws -> [FoodEntry] {
        try dbQueue.read { db in
            let sql = """
                SELECT *, COUNT(*) as cnt, MAX(rowid) as max_rowid FROM food_entry
                GROUP BY name
                ORDER BY cnt DESC, max_rowid DESC
                LIMIT ?
                """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [limit])
            return rows.map { Self.foodEntry(from: $0) }
        }
    }

    /// Maps a database row to a FoodEntry value.
    private static func foodEntry(from row: Row) -> FoodEntry {
        FoodEntry(
            id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
            name: row["name"] as? String ?? "",
            brands: row["brands"] as? String,
            grams: row["grams"] as? Double ?? 100,
            kcalPer100g: row["kcal_per_100g"] as? Double ?? 0,
            proteinsPer100g: row["proteins_per_100g"] as? Double ?? 0,
            carbsPer100g: row["carbs_per_100g"] as? Double ?? 0,
            fatPer100g: row["fat_per_100g"] as? Double ?? 0,
            sugarsPer100g: row["sugars_per_100g"] as? Double,
            saltPer100g: row["salt_per_100g"] as? Double,
            fiberPer100g: row["fiber_per_100g"] as? Double,
            sortOrder: row["sort_order"] as? Int ?? 0
        )
    }

    // MARK: - Previous Meal

    /// Finds the most recent meal of a given type within the lookback window.
    func findLastMealEntries(type: MealType, before date: Date) -> (date: Date, entries: [FoodEntry])? {
        guard let minDate = Calendar.current.date(byAdding: .day, value: -Self.previousMealLookbackDays, to: date) else { return nil }
        let dateStr = date.kcDateString
        let minDateStr = minDate.kcDateString

        let rows = try? dbQueue.read { db in
            let sql = """
                SELECT * FROM food_entry
                WHERE meal_type = ? AND date < ? AND date >= ?
                ORDER BY date DESC, sort_order
                """
            return try Row.fetchAll(db, sql: sql, arguments: [type.rawValue, dateStr, minDateStr])
        }

        guard let rows, !rows.isEmpty else { return nil }

        let grouped = Dictionary(grouping: rows) { $0["date"] as? String ?? "" }
        let sortedDates = grouped.keys.sorted(by: >)

        for dateKey in sortedDates {
            guard let entries = grouped[dateKey], !entries.isEmpty,
                  let foundDate = Date.fromKcDateString(dateKey) else { continue }
            return (date: foundDate, entries: entries.map { Self.foodEntry(from: $0) })
        }

        return nil
    }

    // MARK: - Product Overrides

    /// User-defined nutritional override for a product (or custom food).
    struct ProductOverride: Sendable {
        let code: String
        let kcal: Double
        let proteins: Double?
        let carbs: Double?
        let fat: Double?
        let sugars: Double?
        let salt: Double?
        var fiber: Double?
        var name: String?
        var brands: String?
    }

    /// Loads a product override by its code (EAN or custom:UUID).
    func loadProductOverride(code: String) -> ProductOverride? {
        try? dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM product_override WHERE code = ?",
                arguments: [code]
            ) else { return nil }
            return ProductOverride(
                code: row["code"],
                kcal: row["kcal"],
                proteins: row["proteins"],
                carbs: row["carbs"],
                fat: row["fat"],
                sugars: row["sugars"],
                salt: row["salt"],
                fiber: row["fiber"],
                name: row["name"],
                brands: row["brands"]
            )
        }
    }

    /// Inserts or replaces a product override (upsert on code).
    func saveProductOverride(_ override: ProductOverride) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO product_override (code, kcal, proteins, carbs, fat, sugars, salt, fiber, name, brands)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    override.code,
                    override.kcal,
                    override.proteins,
                    override.carbs,
                    override.fat,
                    override.sugars,
                    override.salt,
                    override.fiber,
                    override.name,
                    override.brands,
                ]
            )
        }
    }

    /// Creates and persists a custom food, returning the generated override.
    func saveCustomFood(name: String, brands: String? = nil, kcal: Double, proteins: Double?, carbs: Double?, fat: Double?, fiber: Double? = nil) -> ProductOverride {
        let code = "\(Self.customCodePrefix)\(UUID().uuidString)"
        let override = ProductOverride(code: code, kcal: kcal, proteins: proteins, carbs: carbs, fat: fat, sugars: nil, salt: nil, fiber: fiber, name: name, brands: brands)
        do { try saveProductOverride(override) }
        catch { logger.error("saveCustomFood failed: \(error)") }
        return override
    }

    /// Searches custom foods by name using SQL LIKE pattern matching.
    func searchCustomFoods(query: String) -> [ProductOverride] {
        guard query.count >= Self.minQueryLength else { return [] }
        // Escape SQL LIKE wildcards: % and _ are special in LIKE patterns,
        // backslash is the ESCAPE char itself — all must be escaped for literal matching.
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return (try? dbQueue.read { db in
            let sql = """
                SELECT * FROM product_override
                WHERE code LIKE '\(Self.customCodePrefix)%' AND name LIKE ? ESCAPE '\\'
                ORDER BY name
                LIMIT \(Self.defaultHistoryLimit)
                """
            let rows = try Row.fetchAll(db, sql: sql, arguments: ["%\(escaped)%"])
            return rows.map { row in
                ProductOverride(
                    code: row["code"],
                    kcal: row["kcal"],
                    proteins: row["proteins"],
                    carbs: row["carbs"],
                    fat: row["fat"],
                    sugars: row["sugars"],
                    salt: row["salt"],
                    fiber: row["fiber"],
                    name: row["name"],
                    brands: row["brands"]
                )
            }
        }) ?? []
    }

    // MARK: - Weight Checkpoints

    /// Goal direction for a weight checkpoint.
    enum CheckpointGoal: String, Sendable, CaseIterable, Identifiable {
        case loss, gain, maintain
        var id: String { rawValue }
        /// Localized display label.
        var label: String {
            switch self {
            case .loss: "Perte"
            case .gain: "Prise"
            case .maintain: "Maintien"
            }
        }
    }

    /// A recorded weight milestone with a title and goal direction.
    struct WeightCheckpoint: Sendable, Identifiable {
        let id: String
        let date: Date
        let weightKg: Double
        let title: String
        let goal: CheckpointGoal
    }

    /// Saves a new weight checkpoint.
    func saveCheckpoint(title: String, weightKg: Double, date: Date, goal: CheckpointGoal) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO weight_checkpoint (id, date, weight_kg, title, goal) VALUES (?, ?, ?, ?, ?)",
                arguments: [UUID().uuidString, date.kcDateString, weightKg, title, goal.rawValue]
            )
        }
    }

    /// Loads all weight checkpoints, most recent first.
    func loadCheckpoints() -> [WeightCheckpoint] {
        (try? dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM weight_checkpoint ORDER BY date DESC")
            return rows.compactMap { row -> WeightCheckpoint? in
                guard let id = row["id"] as? String,
                      let dateStr = row["date"] as? String,
                      let date = Date.fromKcDateString(dateStr),
                      let kg = row["weight_kg"] as? Double,
                      let title = row["title"] as? String,
                      let goalStr = row["goal"] as? String,
                      let goal = CheckpointGoal(rawValue: goalStr) else { return nil }
                return WeightCheckpoint(id: id, date: date, weightKg: kg, title: title, goal: goal)
            }
        }) ?? []
    }

    /// Returns the most recent weight checkpoint, or nil.
    func latestCheckpoint() -> WeightCheckpoint? {
        loadCheckpoints().first
    }

    /// Deletes a weight checkpoint by ID.
    func deleteCheckpoint(id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM weight_checkpoint WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Weight

    /// Records a weight measurement for a given date (upsert).
    func saveWeight(kg: Double, date: Date) throws {
        let dateStr = date.kcDateString
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO weight_entry (date, weight_kg) VALUES (?, ?)",
                arguments: [dateStr, kg]
            )
        }
    }

    /// Loads the most recent weight on or before the given date (not future entries).
    func loadWeight(for date: Date) throws -> Double? {
        try dbQueue.read { db in
            try Double.fetchOne(db, sql: "SELECT weight_kg FROM weight_entry WHERE date <= ? ORDER BY date DESC LIMIT 1", arguments: [date.kcDateString])
        }
    }

    /// Loads weight entries within a date range, ordered chronologically.
    func loadWeights(from start: Date, to end: Date) throws -> [WeightEntry] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT date, weight_kg FROM weight_entry WHERE date >= ? AND date <= ? ORDER BY date",
                arguments: [start.kcDateString, end.kcDateString]
            )
            return rows.compactMap { row -> WeightEntry? in
                guard let dateStr = row["date"] as? String,
                      let date = Date.fromKcDateString(dateStr),
                      let kg = row["weight_kg"] as? Double else { return nil }
                return WeightEntry(id: dateStr, date: date, kg: kg)
            }
        }
    }

    /// Loads the N most recent weight entries, returned in chronological order.
    func latestWeights(limit: Int) throws -> [WeightEntry] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT date, weight_kg FROM weight_entry ORDER BY date DESC LIMIT ?",
                arguments: [limit]
            )
            return rows.compactMap { row -> WeightEntry? in
                guard let dateStr = row["date"] as? String,
                      let date = Date.fromKcDateString(dateStr),
                      let kg = row["weight_kg"] as? Double else { return nil }
                return WeightEntry(id: dateStr, date: date, kg: kg)
            }.reversed()
        }
    }

    // MARK: - Import

    // MARK: - JSON Export/Import

    /// Exports all user data as a JSON dictionary.
    func exportJSON() throws -> Data {
        try dbQueue.read { db in
            var result: [String: Any] = [:]

            result["food_entries"] = try Row.fetchAll(db, sql: "SELECT * FROM food_entry ORDER BY date, meal_type, sort_order").map { row -> [String: Any?] in
                ["id": row["id"] as? String, "date": row["date"] as? String, "meal_type": row["meal_type"] as? String,
                 "name": row["name"] as? String, "brands": row["brands"] as? String,
                 "grams": row["grams"] as? Double, "kcal_per_100g": row["kcal_per_100g"] as? Double,
                 "proteins_per_100g": row["proteins_per_100g"] as? Double, "carbs_per_100g": row["carbs_per_100g"] as? Double,
                 "fat_per_100g": row["fat_per_100g"] as? Double, "sugars_per_100g": row["sugars_per_100g"] as? Double,
                 "salt_per_100g": row["salt_per_100g"] as? Double, "fiber_per_100g": row["fiber_per_100g"] as? Double,
                 "sort_order": row["sort_order"] as? Int]
            }

            if let goalRow = try Row.fetchOne(db, sql: "SELECT * FROM goals LIMIT 1") {
                result["goals"] = ["kcal": goalRow["kcal"] as? Double, "proteins": goalRow["proteins"] as? Double,
                                   "carbs": goalRow["carbs"] as? Double, "fat": goalRow["fat"] as? Double,
                                   "sugars": goalRow["sugars"] as? Double, "salt": goalRow["salt"] as? Double] as [String: Any?]
            }

            result["weight_entries"] = try Row.fetchAll(db, sql: "SELECT * FROM weight_entry ORDER BY date").map { row -> [String: Any?] in
                ["date": row["date"] as? String, "weight_kg": row["weight_kg"] as? Double]
            }

            result["weight_checkpoints"] = try Row.fetchAll(db, sql: "SELECT * FROM weight_checkpoint ORDER BY date").map { row -> [String: Any?] in
                ["id": row["id"] as? String, "date": row["date"] as? String,
                 "weight_kg": row["weight_kg"] as? Double, "title": row["title"] as? String, "goal": row["goal"] as? String]
            }

            result["product_overrides"] = try Row.fetchAll(db, sql: "SELECT * FROM product_override").map { row -> [String: Any?] in
                ["code": row["code"] as? String, "kcal": row["kcal"] as? Double, "proteins": row["proteins"] as? Double,
                 "carbs": row["carbs"] as? Double, "fat": row["fat"] as? Double, "sugars": row["sugars"] as? Double,
                 "salt": row["salt"] as? Double, "fiber": row["fiber"] as? Double,
                 "name": row["name"] as? String, "brands": row["brands"] as? String]
            }

            return try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        }
    }

    /// Imports all user data from a JSON file, replacing existing data in a single transaction.
    func importJSON(from data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UserStoreError.directoryCreationFailed
        }

        try dbQueue.write { db in
            // Food entries
            if let entries = json["food_entries"] as? [[String: Any?]] {
                try db.execute(sql: "DELETE FROM food_entry")
                for e in entries {
                    try db.execute(
                        sql: "INSERT INTO food_entry (id, date, meal_type, name, brands, grams, kcal_per_100g, proteins_per_100g, carbs_per_100g, fat_per_100g, sugars_per_100g, salt_per_100g, fiber_per_100g, sort_order) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        arguments: [(e["id"] as? String)?.uppercased(), e["date"] as? String, e["meal_type"] as? String,
                                    e["name"] as? String, e["brands"] as? String,
                                    e["grams"] as? Double, e["kcal_per_100g"] as? Double,
                                    e["proteins_per_100g"] as? Double, e["carbs_per_100g"] as? Double,
                                    e["fat_per_100g"] as? Double, e["sugars_per_100g"] as? Double,
                                    e["salt_per_100g"] as? Double, e["fiber_per_100g"] as? Double,
                                    e["sort_order"] as? Int ?? 0])
                }
            }

            // Goals
            if let g = json["goals"] as? [String: Any?] {
                try db.execute(sql: "DELETE FROM goals")
                try db.execute(
                    sql: "INSERT INTO goals (kcal, proteins, carbs, fat, sugars, salt) VALUES (?,?,?,?,?,?)",
                    arguments: [g["kcal"] as? Double, g["proteins"] as? Double, g["carbs"] as? Double,
                                g["fat"] as? Double, g["sugars"] as? Double, g["salt"] as? Double])
            }

            // Weight entries
            if let weights = json["weight_entries"] as? [[String: Any?]] {
                try db.execute(sql: "DELETE FROM weight_entry")
                for w in weights {
                    try db.execute(
                        sql: "INSERT INTO weight_entry (date, weight_kg) VALUES (?,?)",
                        arguments: [w["date"] as? String, w["weight_kg"] as? Double])
                }
            }

            // Weight checkpoints
            if let cps = json["weight_checkpoints"] as? [[String: Any?]] {
                try db.execute(sql: "DELETE FROM weight_checkpoint")
                for cp in cps {
                    try db.execute(
                        sql: "INSERT INTO weight_checkpoint (id, date, weight_kg, title, goal) VALUES (?,?,?,?,?)",
                        arguments: [cp["id"] as? String, cp["date"] as? String, cp["weight_kg"] as? Double,
                                    cp["title"] as? String, cp["goal"] as? String])
                }
            }

            // Product overrides
            if let overrides = json["product_overrides"] as? [[String: Any?]] {
                try db.execute(sql: "DELETE FROM product_override")
                for o in overrides {
                    try db.execute(
                        sql: "INSERT INTO product_override (code, kcal, proteins, carbs, fat, sugars, salt, fiber, name, brands) VALUES (?,?,?,?,?,?,?,?,?,?)",
                        arguments: [o["code"] as? String, o["kcal"] as? Double, o["proteins"] as? Double,
                                    o["carbs"] as? Double, o["fat"] as? Double, o["sugars"] as? Double,
                                    o["salt"] as? Double, o["fiber"] as? Double,
                                    o["name"] as? String, o["brands"] as? String])
                }
            }
        }
    }

    /// Copies food entries by ID to a different date/meal, assigning new IDs.
    func copyEntries(ids: Set<UUID>, toDate date: Date, mealType: MealType) throws {
        guard !ids.isEmpty else { return }
        let dateStr = date.kcDateString
        let mealTypeStr = mealType.rawValue

        try dbQueue.write { db in
            let nextOrder: Int = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM food_entry WHERE date = ? AND meal_type = ?",
                arguments: [dateStr, mealTypeStr]
            ) ?? 0

            let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM food_entry WHERE id IN (\(placeholders)) ORDER BY sort_order",
                arguments: StatementArguments(ids.map { $0.uuidString })
            )

            for (i, row) in rows.enumerated() {
                let sql = """
                    INSERT INTO food_entry (id, date, meal_type, name, brands, grams, kcal_per_100g, proteins_per_100g, carbs_per_100g, fat_per_100g, sugars_per_100g, salt_per_100g, fiber_per_100g, sort_order)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """
                try db.execute(sql: sql, arguments: [
                    UUID().uuidString,
                    dateStr,
                    mealTypeStr,
                    row["name"] as? String ?? "",
                    row["brands"] as? String,
                    row["grams"] as? Double ?? 0,
                    row["kcal_per_100g"] as? Double ?? 0,
                    row["proteins_per_100g"] as? Double ?? 0,
                    row["carbs_per_100g"] as? Double ?? 0,
                    row["fat_per_100g"] as? Double ?? 0,
                    row["sugars_per_100g"] as? Double,
                    row["salt_per_100g"] as? Double,
                    row["fiber_per_100g"] as? Double,
                    nextOrder + i,
                ])
            }
        }
    }
}
