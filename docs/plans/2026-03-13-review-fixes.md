# Review Fixes — F4+F5 Debt Cleanup

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Corriger les 26 findings de la review F4+F5 avant d'attaquer F6 (persistance).

**Architecture:** 5 batches séquentiels (P0→P3). Chaque batch est un commit atomique. Pas de TDD ici (pas de test target dans le projet), on vérifie par build xcodegen + xcodebuild.

**Tech Stack:** Swift 6, SwiftUI, GRDB 7, xcodegen

---

### Task 1: P0 — OFFStore (retirer @MainActor, throw au lieu de fatalError, sanitize FTS)

**Files:**
- Modify: `kcalz/Stores/OFFStore.swift`

**Step 1: Réécrire OFFStore**

```swift
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
            .map { "\($0.replacingOccurrences(of: "\"", with: ""))"  + "*" }
            .map { "\"\($0)\"" }
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
```

Key changes:
- `@MainActor` retiré — GRDB `DatabaseQueue` readonly est thread-safe
- `Sendable` conservé (pas de mutable state)
- `fatalError` → `throw OFFStoreError.databaseNotFound`
- Sanitize: `replacingOccurrences(of: "\"", with: "")` avant wrap en quotes FTS

**Step 2: Build pour vérifier**

Run: `cd /Users/rbaumier/www/kcalz && xcodegen generate && xcodebuild build -project kcalz.xcodeproj -scheme kcalz -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
fix: P0 OFFStore — retirer @MainActor, throw au lieu de fatalError, sanitize FTS
```

---

### Task 2: P0 — KcalzApp (gestion d'erreur explicite)

**Files:**
- Modify: `kcalz/App/KcalzApp.swift`

**Step 1: Réécrire KcalzApp avec AppState**

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
                            let store = try OFFStore()
                            appState = .ready(store)
                        } catch {
                            appState = .failed(error)
                        }
                    }
            case .ready(let store):
                DashboardView(offStore: store)
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
    case ready(OFFStore)
    case failed(Error)
}
```

Key changes:
- `try?` → `do/catch` avec état d'erreur
- `.onAppear` → `.task`
- `AppState` enum pour rendre chaque état explicite

**Step 2: Build**

**Step 3: Commit**

```
fix: P0 KcalzApp — AppState enum, gestion erreur explicite, .task
```

---

### Task 3: P1 — SearchViewModel (encapsulation, erreur, clearSearch)

**Files:**
- Modify: `kcalz/ViewModels/SearchViewModel.swift`
- Modify: `kcalz/Views/Search/SearchView.swift` (appel clearSearch au lieu de mutation directe)

**Step 1: Réécrire SearchViewModel**

```swift
import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    private(set) var results: [OFFProduct] = []
    private(set) var isSearching = false
    private(set) var error: Error?

    private let store: OFFStore
    private var searchTask: Task<Void, Never>?

    init(store: OFFStore) {
        self.store = store
    }

    func onQueryChanged() {
        searchTask?.cancel()
        error = nil

        guard query.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            do {
                let found = try store.search(query: query)
                if !Task.isCancelled {
                    results = found
                    isSearching = false
                }
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled {
                    self.error = error
                    results = []
                    isSearching = false
                }
            }
        }
    }

    func clearSearch() {
        query = ""
        results = []
        error = nil
        isSearching = false
        searchTask?.cancel()
    }
}
```

**Step 2: Dans SearchView.swift, remplacer la mutation directe**

Remplacer :
```swift
Button {
    viewModel.query = ""
    viewModel.results = []
}
```

Par :
```swift
Button {
    viewModel.clearSearch()
}
```

Et remplacer `.onAppear { isSearchFocused = true }` par `.task { isSearchFocused = true }`.

**Step 3: Build**

**Step 4: Commit**

```
fix: P1 SearchViewModel — encapsulation private(set), clearSearch(), error state
```

---

### Task 4: P1 — ProductDetailViewModel (validation input, scaled helper)

**Files:**
- Modify: `kcalz/ViewModels/ProductDetailViewModel.swift`
- Modify: `kcalz/Views/Search/ProductDetailView.swift` (désactiver bouton, `.decimalPad`)

**Step 1: Réécrire ProductDetailViewModel**

```swift
import Foundation

@Observable
@MainActor
final class ProductDetailViewModel {
    let product: OFFProduct
    var gramsText = "100"

    init(product: OFFProduct) {
        self.product = product
    }

    var grams: Double? {
        guard let v = Double(gramsText), v > 0 else { return nil }
        return v
    }

    var isValidInput: Bool { grams != nil }

    var kcal: Double { scaled(product.kcal) }
    var proteins: Double { scaled(product.proteins) }
    var carbs: Double { scaled(product.carbs) }
    var fat: Double { scaled(product.fat) }
    var sugars: Double { scaled(product.sugars) }
    var salt: Double { scaled(product.salt) }

    private func scaled(_ valuePer100g: Double?) -> Double {
        (valuePer100g ?? 0) * (grams ?? 0) / 100
    }

    func makeFoodEntry() -> FoodEntry {
        FoodEntry(
            name: product.name,
            grams: grams ?? 0,
            kcalPer100g: product.kcal ?? 0,
            proteinsPer100g: product.proteins ?? 0,
            carbsPer100g: product.carbs ?? 0,
            fatPer100g: product.fat ?? 0,
            sugarsPer100g: product.sugars,
            saltPer100g: product.salt
        )
    }
}
```

**Step 2: Dans ProductDetailView.swift :**

- `.keyboardType(.numberPad)` → `.keyboardType(.decimalPad)`
- Ajouter `.disabled(!viewModel.isValidInput)` et `.opacity(viewModel.isValidInput ? 1 : 0.5)` sur le bouton "Ajouter"

**Step 3: Build**

**Step 4: Commit**

```
fix: P1 ProductDetailViewModel — validation input, scaled(), decimalPad
```

---

### Task 5: P1 — Models (Sendable, Equatable, Hashable)

**Files:**
- Modify: `kcalz/Models/FoodEntry.swift`
- Modify: `kcalz/Models/Meal.swift`
- Modify: `kcalz/Models/DayLog.swift`
- Modify: `kcalz/Models/MealType.swift`

**Step 1: FoodEntry**

```swift
import Foundation

struct FoodEntry: Identifiable, Sendable, Hashable {
    let id = UUID()
    var name: String
    var grams: Double
    var kcalPer100g: Double
    var proteinsPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarsPer100g: Double?
    var saltPer100g: Double?

    var kcal: Double { kcalPer100g * grams / 100 }
    var proteins: Double { proteinsPer100g * grams / 100 }
    var carbs: Double { carbsPer100g * grams / 100 }
    var fat: Double { fatPer100g * grams / 100 }

    static func == (lhs: FoodEntry, rhs: FoodEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

**Step 2: MealType — rawValue anglais + displayName**

```swift
import Foundation

enum MealType: String, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case snack
    case dinner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Petit déjeuner"
        case .lunch: "Déjeuner"
        case .snack: "Goûter"
        case .dinner: "Dîner"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .snack: "cup.and.saucer.fill"
        case .dinner: "moon.fill"
        }
    }
}
```

**Step 3: Meal**

```swift
import Foundation

struct Meal: Identifiable, Sendable, Hashable {
    let id = UUID()
    var type: MealType
    var entries: [FoodEntry]

    var totalKcal: Double { entries.reduce(0) { $0 + $1.kcal } }
    var totalProteins: Double { entries.reduce(0) { $0 + $1.proteins } }
    var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }

    static func == (lhs: Meal, rhs: Meal) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

**Step 4: DayLog**

```swift
import Foundation

struct DayLog: Identifiable, Sendable, Equatable {
    let id = UUID()
    var date: Date
    var meals: [Meal]
    var weight: Double?

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

**Step 5: Grep toutes les occurrences de `.rawValue` utilisées comme label et remplacer par `.displayName`**

Fichiers impactés :
- `MealSectionView.swift:15` → `meal.type.displayName`
- `MealSectionView.swift:41` → `meal.type.displayName`

**Step 6: Build**

**Step 7: Commit**

```
fix: P1 Models — Sendable/Equatable/Hashable, MealType rawValue anglais
```

---

### Task 6: P2 — Theme.swift (design tokens, fonts, spacing)

**Files:**
- Modify: `kcalz/Utils/Theme.swift`

**Step 1: Étendre Theme.swift**

Ajouter après les fonts existantes :

```swift
// MARK: - Font tokens — inline sizes used in views

extension Font {
    /// 11pt heavy rounded — section labels (CONSOMMÉ, QUANTITÉ, RESTANTES)
    static let kcLabel = Font.system(size: 11, weight: .heavy, design: .rounded)
    /// 13pt heavy rounded — nutrient bar labels
    static let kcSmallLabel = Font.system(size: 13, weight: .heavy, design: .rounded)
    /// 13pt black rounded — nutrient bar values
    static let kcSmallNumber = Font.system(size: 13, weight: .black, design: .rounded)
    /// 12pt bold rounded — nutrient bar units, kcal suffix
    static let kcUnit = Font.system(size: 12, weight: .bold, design: .rounded)
    /// 14pt bold — icon buttons (chevrons, plus)
    static let kcIcon = Font.system(size: 14, weight: .bold)
    /// 16pt bold — search/clear icons
    static let kcIconMedium = Font.system(size: 16, weight: .bold)
    /// 28pt bold — empty state icons
    static let kcIconLarge = Font.system(size: 28, weight: .bold)
    /// 15pt heavy rounded — secondary values (goal suffix)
    static let kcSecondary = Font.system(size: 15, weight: .heavy, design: .rounded)
    /// 15pt bold rounded — empty state text
    static let kcEmptyText = Font.system(size: 15, weight: .bold, design: .rounded)
    /// 34pt black rounded — ring center number
    static let kcNumberLarge = Font.system(size: 34, weight: .black, design: .rounded)
    /// 14pt bold rounded — grams badge in meal entries
    static let kcBadge = Font.system(size: 14, weight: .bold, design: .rounded)
}

// MARK: - Spacing & Layout tokens

enum Theme {
    // Corner radii
    static let cornerRadiusS: CGFloat = 12
    static let cornerRadiusM: CGFloat = 14
    static let cornerRadiusL: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20

    // Padding
    static let horizontalPadding: CGFloat = 16
    static let cardInnerPadding: CGFloat = 20

    // Sizing
    static let buttonSize: CGFloat = 44
    static let dotSize: CGFloat = 10
    static let barHeight: CGFloat = 10
    static let ringSize: CGFloat = 130
    static let ringStroke: CGFloat = 12
    static let minBarWidth: CGFloat = 10

    // Label kerning
    static let labelKerning: CGFloat = 0.8
    static let ringLabelKerning: CGFloat = 0.6
}
```

Supprimer `kcSmooth` (code mort) :

```swift
// Delete this line:
static let kcSmooth = Animation.easeOut(duration: 0.5)
```

Ajouter `Sendable` à `Kc3DButton` :

```swift
struct Kc3DButton: ButtonStyle, Sendable {
```

**Step 2: Build**

**Step 3: Commit**

```
refactor: P2 Theme — design tokens fonts/spacing/layout, supprimer kcSmooth
```

---

### Task 7: P2 — Remplacer magic numbers dans toutes les vues

**Files:**
- Modify: `kcalz/Views/Dashboard/DashboardView.swift`
- Modify: `kcalz/Views/Components/MealSectionView.swift`
- Modify: `kcalz/Views/Components/NutrientBarView.swift`
- Modify: `kcalz/Views/Components/KcalRingView.swift`
- Modify: `kcalz/Views/Search/SearchView.swift`
- Modify: `kcalz/Views/Search/ProductDetailView.swift`

**Step 1: DashboardView.swift**

Remplacements :
- `DateFormatter()` → `static let` privé
- `.font(.system(size: 14, weight: .bold))` (chevrons) → `.font(.kcIcon)`
- `.frame(width: 44, height: 44)` → `.frame(width: Theme.buttonSize, height: Theme.buttonSize)`
- `.clipShape(RoundedRectangle(cornerRadius: 14` → `Theme.cornerRadiusM`
- `.padding(.horizontal, 20)` (date nav) → `Theme.cardInnerPadding`
- `.font(.system(size: 11, weight: .heavy, design: .rounded))` → `.font(.kcLabel)`
- `.kerning(0.8)` → `.kerning(Theme.labelKerning)`
- `.font(.system(size: 15, weight: .heavy, design: .rounded))` → `.font(.kcSecondary)`
- `.padding(.horizontal, 20)` (summary) → `Theme.cardInnerPadding`
- `.padding(.horizontal, 16)` (meals) → `Theme.horizontalPadding`
- `KcalRingView(consumed:goal:)` → `goal: goal.kcal` type change (`Int` → `Double`, voir Task 8)
- `.onAppear` animations → `.task` (P3 #21)
- `#Preview { try! OFFStore() }` → `try? OFFStore()` safe (P3 #24)

Extraire `dateText` avec DateFormatter statique :

```swift
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "fr_FR")
    f.dateFormat = "EEEE d MMMM"
    return f
}()

private var dateText: String {
    Self.dateFormatter.string(from: dayLog.date).capitalized
}
```

**Step 2: MealSectionView.swift**

- `var onAdd` → `let onAdd`
- `.font(.system(size: 12, weight: .bold, design: .rounded))` → `.font(.kcUnit)`
- `.font(.system(size: 16, weight: .bold))` (plus icon) → `.font(.kcIconMedium)`
- `.frame(width: 44, height: 36)` → `.frame(width: Theme.buttonSize, height: 36)`
- `.clipShape(RoundedRectangle(cornerRadius: 12` → `Theme.cornerRadiusS`
- `.font(.system(size: 14, weight: .bold))` (empty icon) → `.font(.kcIcon)`
- `.font(.system(size: 15, weight: .bold, design: .rounded))` → `.font(.kcEmptyText)`
- `.clipShape(RoundedRectangle(cornerRadius: 20` → `Theme.cornerRadiusXL`
- `.padding(.horizontal, 20)` → `Theme.cardInnerPadding`
- `.padding(.leading, 20)` → `Theme.cardInnerPadding`
- `.font(.system(size: 14, weight: .bold, design: .rounded))` (grams) → `.font(.kcBadge)`
- `.onAppear` → `.task`

**Step 3: NutrientBarView.swift**

- `.font(.system(size: 13, weight: .heavy, design: .rounded))` → `.font(.kcSmallLabel)`
- `10 :` (min bar width) → `Theme.minBarWidth`
- `.frame(height: 10)` → `Theme.barHeight`
- `.font(.system(size: 13, weight: .black, design: .rounded))` → `.font(.kcSmallNumber)`
- `.font(.system(size: 12, weight: .bold, design: .rounded))` → `.font(.kcUnit)`
- `.onAppear` → `.task`

**Step 4: KcalRingView.swift**

- `goal: Int` → `goal: Double` (harmoniser)
- `Double(goal)` → `goal` partout
- `Int(consumed)` casts restent
- `.font(.system(size: 34, weight: .black, design: .rounded))` → `.font(.kcNumberLarge)`
- `.font(.system(size: 11, weight: .heavy, design: .rounded))` → `.font(.kcLabel)`
- `.kerning(0.6)` → `.kerning(Theme.ringLabelKerning)`
- `lineWidth: 12` → `Theme.ringStroke`
- `.frame(width: 130, height: 130)` → `Theme.ringSize`
- `.onAppear` → `.task`

**Step 5: SearchView.swift**

- `.font(.system(size: 16, weight: .bold))` (×2) → `.font(.kcIconMedium)`
- `.clipShape(RoundedRectangle(cornerRadius: 16` → `Theme.cornerRadiusL`
- `.padding(.horizontal, 16)` → `Theme.horizontalPadding`
- `.font(.system(size: 28, weight: .bold))` (×2) → `.font(.kcIconLarge)`
- `.clipShape(RoundedRectangle(cornerRadius: 20` → `Theme.cornerRadiusXL`
- `.padding(.horizontal, 20)` → `Theme.cardInnerPadding`
- `.padding(.leading, 20)` → `Theme.cardInnerPadding`

**Step 6: ProductDetailView.swift**

- `.padding(.horizontal, 20)` → `Theme.cardInnerPadding`
- `.font(.system(size: 11, weight: .heavy, design: .rounded))` → `.font(.kcLabel)`
- `.kerning(0.8)` → `.kerning(Theme.labelKerning)`
- `.clipShape(RoundedRectangle(cornerRadius: 14` → `Theme.cornerRadiusM`
- `.clipShape(RoundedRectangle(cornerRadius: 20` → `Theme.cornerRadiusXL`
- `.padding(.horizontal, 16)` → `Theme.horizontalPadding`
- `.clipShape(RoundedRectangle(cornerRadius: 16` → `Theme.cornerRadiusL`
- `.frame(width: 10, height: 10)` (dot) → `Theme.dotSize`
- `.padding(.horizontal, 20)` (row) → `Theme.cardInnerPadding`

**Step 7: Build**

**Step 8: Commit**

```
refactor: P2 remplacer magic numbers par design tokens Theme
```

---

### Task 8: P2 — Architecture (NutritionGoal, Route, PreviewData, goal Double)

**Files:**
- Create: `kcalz/Models/NutritionGoal.swift`
- Create: `kcalz/Models/Route.swift`
- Modify: `kcalz/Models/PreviewData.swift`
- Modify: `kcalz/Views/Dashboard/DashboardView.swift` (retirer Route enum, utiliser NutritionGoal)

**Step 1: Créer NutritionGoal**

```swift
import Foundation

struct NutritionGoal: Sendable, Equatable {
    let kcal: Double
    let proteins: Double
    let carbs: Double
    let fat: Double
}
```

**Step 2: Créer Route.swift**

```swift
import Foundation

enum Route: Hashable {
    case search(MealType)
    case detail(OFFProduct, MealType)
}
```

**Step 3: Réécrire PreviewData avec entries de test**

```swift
import Foundation

enum PreviewData {
    static let goal = NutritionGoal(kcal: 2200, proteins: 140, carbs: 250, fat: 80)

    static let dayLog = DayLog(
        date: .now,
        meals: [
            Meal(type: .breakfast, entries: []),
            Meal(type: .lunch, entries: []),
            Meal(type: .snack, entries: []),
            Meal(type: .dinner, entries: []),
        ]
    )

    static let dayLogWithEntries = DayLog(
        date: .now,
        meals: [
            Meal(type: .breakfast, entries: [
                FoodEntry(name: "Flocons d'avoine", grams: 80, kcalPer100g: 379, proteinsPer100g: 13.5, carbsPer100g: 67.7, fatPer100g: 6.5),
                FoodEntry(name: "Lait demi-écrémé", grams: 200, kcalPer100g: 46, proteinsPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 1.6),
            ]),
            Meal(type: .lunch, entries: [
                FoodEntry(name: "Poulet grillé", grams: 150, kcalPer100g: 165, proteinsPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
                FoodEntry(name: "Riz basmati", grams: 200, kcalPer100g: 130, proteinsPer100g: 2.7, carbsPer100g: 28.2, fatPer100g: 0.3),
            ]),
            Meal(type: .snack, entries: []),
            Meal(type: .dinner, entries: []),
        ]
    )
}
```

**Step 4: DashboardView — retirer Route enum, utiliser NutritionGoal**

- Supprimer `enum Route: Hashable { ... }` du début du fichier
- `let goal = PreviewData.goal` → `private let goal = PreviewData.goal` (type inféré `NutritionGoal`)
- `goal.kcal` : déjà `Double` maintenant, pas besoin de cast

**Step 5: Build**

**Step 6: Commit**

```
refactor: P2 Architecture — NutritionGoal struct, Route propre fichier, PreviewData enrichi
```

---

### Task 9: P3 — Accessibilité

**Files:**
- Modify: `kcalz/Views/Search/SearchView.swift`
- Modify: `kcalz/Views/Search/ProductDetailView.swift`
- Modify: `kcalz/Views/Components/MealSectionView.swift`

**Step 1: SearchView — accessibilité résultats**

Sur le `Button` dans `ForEach(viewModel.results)`, ajouter :
```swift
.accessibilityLabel("\(product.name), \(product.brands ?? ""), \(Int(product.kcal ?? 0)) kilocalories pour 100 grammes")
```

Sur le `ProgressView`, ajouter :
```swift
.accessibilityLabel("Recherche en cours")
```

**Step 2: ProductDetailView — hint bouton**

Sur le bouton "Ajouter", ajouter :
```swift
.accessibilityHint("Ajoute cet aliment au repas")
```

**Step 3: MealSectionView — entrées**

Sur chaque `HStack` d'entrée, ajouter :
```swift
.accessibilityElement(children: .combine)
```

**Step 4: Build**

**Step 5: Commit**

```
fix: P3 accessibilité — labels résultats recherche, hint bouton, combine entries
```

---

## Résumé des commits

| # | Message | Findings |
|---|---------|----------|
| 1 | `fix: P0 OFFStore — @MainActor, throw, sanitize FTS` | #1, #2, #3 |
| 2 | `fix: P0 KcalzApp — AppState, gestion erreur, .task` | #4, #21 (partiel) |
| 3 | `fix: P1 SearchViewModel — encapsulation, error state` | #7, #8 |
| 4 | `fix: P1 ProductDetailViewModel — validation, scaled, decimalPad` | #5, #15, #20, #26 |
| 5 | `fix: P1 Models — Sendable/Equatable, MealType rawValue` | #6, #9, #11 |
| 6 | `refactor: P2 Theme — design tokens` | #12, #19, #22 |
| 7 | `refactor: P2 magic numbers → tokens` | #10, #12, #13, #17, #18, #21 |
| 8 | `refactor: P2 Architecture — NutritionGoal, Route, PreviewData` | #10, #16, #24 |
| 9 | `fix: P3 accessibilité` | #23, #25 |
