# F6 — Persistance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Persister les food entries dans une base SQLite user read-write (Application Support), avec auto-save immédiat à chaque ajout.

**Architecture:** `UserStore` GRDB read-write, séparé de `OFFStore` (read-only). Une seule table `food_entry` avec date TEXT ISO 8601. `DayLog` reconstruit à la volée depuis les entries groupées par `meal_type`. Le `@State dayLog` dans `DashboardView` est synchronisé avec la DB à chaque mutation.

**Tech Stack:** Swift 6, GRDB 7, SwiftUI

---

### Task 1: Créer UserStore avec migration

**Files:**
- Create: `kcalz/Stores/UserStore.swift`

**Step 1: Créer UserStore**

```swift
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

        var config = Configuration()
        config.prepareDatabase { db in
            db.trace { print("SQL: \($0)") }
        }

        dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)
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
}
```

**Step 2: Build**

Run: `xcodegen generate && xcodebuild build -project kcalz.xcodeproj -scheme kcalz -sdk iphonesimulator -destination 'id=67080FA6-9061-46B3-A900-C59F47616CAE' 2>&1 | grep -E '(error:|BUILD)' | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat(F6): créer UserStore avec migration v1
```

---

### Task 2: FoodEntry — ajouter sortOrder + dateString helper

**Files:**
- Modify: `kcalz/Models/FoodEntry.swift`

**Step 1: Ajouter sortOrder à FoodEntry**

```swift
import Foundation

struct FoodEntry: Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var grams: Double
    var kcalPer100g: Double
    var proteinsPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarsPer100g: Double?
    var saltPer100g: Double?
    var sortOrder: Int

    var kcal: Double { kcalPer100g * grams / 100 }
    var proteins: Double { proteinsPer100g * grams / 100 }
    var carbs: Double { carbsPer100g * grams / 100 }
    var fat: Double { fatPer100g * grams / 100 }

    init(
        id: UUID = UUID(),
        name: String,
        grams: Double,
        kcalPer100g: Double,
        proteinsPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        sugarsPer100g: Double? = nil,
        saltPer100g: Double? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.grams = grams
        self.kcalPer100g = kcalPer100g
        self.proteinsPer100g = proteinsPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.sugarsPer100g = sugarsPer100g
        self.saltPer100g = saltPer100g
        self.sortOrder = sortOrder
    }

    static func == (lhs: FoodEntry, rhs: FoodEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

Key changes:
- `let id = UUID()` → `let id: UUID` avec default dans init (nécessaire pour reconstruire depuis la DB)
- Ajout `sortOrder: Int` avec default 0
- Init explicite avec tous les defaults pour ne rien casser

**Step 2: Ajouter un helper date string**

Créer une extension pour formater les dates en ISO 8601 date-only. Ajouter dans un nouveau fichier ou dans un fichier existant :

Create: `kcalz/Utils/DateFormatting.swift`

```swift
import Foundation

extension Date {
    var kcDateString: String {
        Self.kcDateFormatter.string(from: self)
    }

    static func fromKcDateString(_ s: String) -> Date? {
        kcDateFormatter.date(from: s)
    }

    private static let kcDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
}
```

**Step 3: Build**

**Step 4: Commit**

```
feat(F6): FoodEntry sortOrder + DateFormatting helper
```

---

### Task 3: UserStore — CRUD operations

**Files:**
- Modify: `kcalz/Stores/UserStore.swift`

**Step 1: Ajouter loadDayLog**

```swift
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
```

**Step 2: Ajouter addEntry**

```swift
func addEntry(_ entry: FoodEntry, date: Date, mealType: MealType) throws {
    let dateStr = date.kcDateString

    // Get next sort order
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
```

**Step 3: Ajouter deleteEntry**

```swift
func deleteEntry(id: UUID) throws {
    try dbQueue.write { db in
        try db.execute(sql: "DELETE FROM food_entry WHERE id = ?", arguments: [id.uuidString])
    }
}
```

**Step 4: Build**

**Step 5: Commit**

```
feat(F6): UserStore CRUD — loadDayLog, addEntry, deleteEntry
```

---

### Task 4: Intégrer UserStore dans KcalzApp

**Files:**
- Modify: `kcalz/App/KcalzApp.swift`

**Step 1: Créer les deux stores et les passer à DashboardView**

```swift
import SwiftUI

@main
struct KcalzApp: App {
    @State private var appState = AppState.loading

    var body: some Scene {
        WindowGroup {
            switch appState {
            case .loading:
                Color.kcPolar
                    .ignoresSafeArea()
                    .task {
                        do {
                            let offStore = try OFFStore()
                            let userStore = try UserStore()
                            appState = .ready(offStore, userStore)
                        } catch {
                            appState = .failed(error)
                        }
                    }
            case .ready(let offStore, let userStore):
                DashboardView(offStore: offStore, userStore: userStore)
            case .failed(let error):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.kcCardinal)
                    Text("Impossible de charger la base")
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcEel)
                    Text(error.localizedDescription)
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcWolf)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kcPolar)
                .ignoresSafeArea()
            }
        }
    }
}

private enum AppState {
    case loading
    case ready(OFFStore, UserStore)
    case failed(Error)
}
```

**Step 2: Build**

**Step 3: Commit**

```
feat(F6): intégrer UserStore dans KcalzApp
```

---

### Task 5: DashboardView — charger et persister via UserStore

**Files:**
- Modify: `kcalz/Views/Dashboard/DashboardView.swift`

**Step 1: Ajouter userStore, charger au lancement, persister à l'ajout**

Changements clés dans DashboardView :

- Ajouter `let userStore: UserStore`
- `@State private var dayLog = ...` → initialisé depuis `userStore.loadDayLog` dans `.task`
- `addEntry()` → appeler `userStore.addEntry()` avant de mettre à jour le state
- Retirer l'init depuis `PreviewData.dayLog` (utiliser un DayLog vide par défaut)

```swift
import SwiftUI

struct DashboardView: View {
    let offStore: OFFStore
    let userStore: UserStore

    @State private var dayLog: DayLog?
    private let goal = PreviewData.goal

    @State private var path: [Route] = []
    @State private var headerAppeared = false
    @State private var summaryAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private var dateText: String {
        guard let dayLog else { return "" }
        return Self.dateFormatter.string(from: dayLog.date).capitalized
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let dayLog {
                    dayContent(dayLog)
                } else {
                    Color.kcPolar.ignoresSafeArea()
                }
            }
            .background(Color.kcPolar)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .search(let mealType):
                    SearchView(store: offStore) { product in
                        path.append(.detail(product, mealType))
                    }
                case .detail(let product, let mealType):
                    ProductDetailView(product: product) { entry in
                        addEntry(entry, to: mealType)
                        path = []
                    }
                }
            }
            .task {
                loadToday()
                if reduceMotion {
                    headerAppeared = true
                    summaryAppeared = true
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        headerAppeared = true
                    }
                    withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                        summaryAppeared = true
                    }
                }
            }
        }
    }

    // Extract the ScrollView content into a private method
    @ViewBuilder
    private func dayContent(_ dayLog: DayLog) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Date navigation — same as before but using tokens
                HStack {
                    Button { } label: {
                        Image(systemName: "chevron.left")
                            .font(.kcIcon)
                            .foregroundStyle(Color.kcWolf)
                            .frame(width: Theme.buttonSize, height: Theme.buttonSize)
                            .background(Color.kcSnow)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM, style: .continuous))
                    }
                    .buttonStyle(Kc3DButton(shadow: Color.kcSwan))
                    .accessibilityLabel("Jour précédent")

                    Spacer()

                    Text(dateText)
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcEel)

                    Spacer()

                    Button { } label: {
                        Image(systemName: "chevron.right")
                            .font(.kcIcon)
                            .foregroundStyle(Color.kcWolf)
                            .frame(width: Theme.buttonSize, height: Theme.buttonSize)
                            .background(Color.kcSnow)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM, style: .continuous))
                    }
                    .buttonStyle(Kc3DButton(shadow: Color.kcSwan))
                    .accessibilityLabel("Jour suivant")
                }
                .padding(.horizontal, Theme.cardInnerPadding)
                .padding(.top, 6)
                .padding(.bottom, 16)
                .opacity(headerAppeared ? 1 : 0)

                // Summary
                VStack(spacing: 0) {
                    HStack(spacing: 20) {
                        KcalRingView(consumed: dayLog.totalKcal, goal: goal.kcal)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CONSOMMÉ")
                                .font(.kcLabel)
                                .foregroundStyle(Color.kcWolf)
                                .kerning(Theme.labelKerning)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(dayLog.totalKcal))")
                                    .font(.kcNumberMedium)
                                    .foregroundStyle(Color.kcFeather)
                                Text("/ \(Int(goal.kcal)) kcal")
                                    .font(.kcSecondary)
                                    .foregroundStyle(Color.kcWolf)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 28)

                    VStack(spacing: 12) {
                        NutrientBarView(label: "Protéines", current: dayLog.totalProteins, goal: goal.proteins, color: .kcCardinal, index: 0)
                        NutrientBarView(label: "Glucides", current: dayLog.totalCarbs, goal: goal.carbs, color: .kcMacaw, index: 1)
                        NutrientBarView(label: "Lipides", current: dayLog.totalFat, goal: goal.fat, color: .kcBee, index: 2)
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, Theme.cardInnerPadding)
                .opacity(summaryAppeared ? 1 : 0)
                .offset(y: summaryAppeared ? 0 : 16)

                // Meals
                VStack(spacing: 24) {
                    ForEach(Array(dayLog.meals.enumerated()), id: \.element.id) { i, meal in
                        MealSectionView(meal: meal, index: i) {
                            path.append(.search(meal.type))
                        }
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.bottom, 44)
            }
        }
    }

    private func loadToday() {
        dayLog = try? userStore.loadDayLog(for: .now)
    }

    private func addEntry(_ entry: FoodEntry, to mealType: MealType) {
        guard var log = dayLog else { return }
        try? userStore.addEntry(entry, date: log.date, mealType: mealType)
        guard let idx = log.meals.firstIndex(where: { $0.type == mealType }) else { return }
        log.meals[idx].entries.append(entry)
        dayLog = log
    }
}

#Preview {
    if let offStore = try? OFFStore(), let userStore = try? UserStore() {
        DashboardView(offStore: offStore, userStore: userStore)
    }
}
```

**Step 2: Build**

**Step 3: Commit**

```
feat(F6): DashboardView — charger/persister via UserStore
```

---

### Task 6: Retirer DayLog.weight + nettoyer

**Files:**
- Modify: `kcalz/Models/DayLog.swift`

**Step 1: Retirer weight de DayLog**

```swift
import Foundation

struct DayLog: Identifiable, Sendable, Equatable {
    let id = UUID()
    var date: Date
    var meals: [Meal]

    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalKcal } }
    var totalProteins: Double { meals.reduce(0) { $0 + $1.totalProteins } }
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { meals.reduce(0) { $0 + $1.totalFat } }

    func meal(for type: MealType) -> Meal? {
        meals.first { $0.type == type }
    }

    static func == (lhs: DayLog, rhs: DayLog) -> Bool { lhs.id == rhs.id }
}
```

**Step 2: Retirer le trace SQL du UserStore (debug only)**

Dans `UserStore.init()`, supprimer le bloc `config.prepareDatabase { db in db.trace { ... } }` (ou le garder sous `#if DEBUG`).

**Step 3: Build**

**Step 4: Commit**

```
feat(F6): retirer DayLog.weight, nettoyer UserStore
```

---

## Résumé des commits

| # | Message | Description |
|---|---------|-------------|
| 1 | `feat(F6): créer UserStore avec migration v1` | Table food_entry, index date |
| 2 | `feat(F6): FoodEntry sortOrder + DateFormatting` | Modèle prêt pour la DB |
| 3 | `feat(F6): UserStore CRUD` | loadDayLog, addEntry, deleteEntry |
| 4 | `feat(F6): intégrer UserStore dans KcalzApp` | AppState avec deux stores |
| 5 | `feat(F6): DashboardView charger/persister` | Auto-save à l'ajout |
| 6 | `feat(F6): retirer DayLog.weight, nettoyer` | Cleanup |
