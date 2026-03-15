# F24 — Fibres Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ajouter le suivi des fibres avec objectif automatique de 15g/1000 kcal.

**Architecture:** Propager `fiber` dans toute la chaîne : off-reduce → off-to-sqlite → OFFProduct → FoodEntry → DayLog/Meal → Dashboard. Objectif calculé automatiquement, pas configurable.

**Tech Stack:** Rust (off-reduce, off-to-sqlite), Swift 6 / SwiftUI / GRDB

---

### Task 1: off-reduce — extraire fiber du dump OFF

**Files:**
- Modify: `tools/off-reduce/src/main.rs`

**Step 1: Ajouter fiber aux structs**

Dans `Nutriments`, ajouter :
```rust
fiber_100g: Option<f64>,
```

Dans `AggregatedNutrients`, ajouter :
```rust
fiber: Option<NutrientEntry>,
```

**Step 2: Extraire fiber dans process_line**

Après la ligne `let salt = ...` (ligne ~113), ajouter :
```rust
let fiber = product.nutriments.fiber_100g
    .or_else(|| agg_val(ag?.fiber.as_ref()));
```

**Step 3: Passer fiber à write_product**

Modifier la signature de `write_product` pour ajouter `fiber: Option<f64>`.

Modifier l'appel (ligne ~122) :
```rust
write_product(&mut out, code, name, &product, kcal, proteins, carbs, fat, sugars, salt, fiber);
```

**Step 4: Écrire fiber dans le JSONL**

Dans `write_product`, après le bloc `salt`, ajouter :
```rust
if let Some(v) = fiber {
    w.extend_from_slice(b",\"fiber\":");
    let mut buf = ryu::Buffer::new();
    w.extend_from_slice(buf.format(v).as_bytes());
}
```

**Step 5: Build**

```bash
cd tools/off-reduce && cargo build --release
```

**Step 6: Commit**

```
feat: off-reduce — extraire fiber du dump OFF
```

---

### Task 2: off-to-sqlite — colonne fiber

**Files:**
- Modify: `tools/off-to-sqlite/src/main.rs`

**Step 1: Ajouter fiber au struct Product**

```rust
fiber: Option<f64>,
```

**Step 2: Ajouter colonne au CREATE TABLE**

Après `salt REAL,` :
```sql
fiber REAL,
```

**Step 3: Ajouter au INSERT**

Mettre à jour le SQL d'insertion pour inclure `fiber` et le `rusqlite::params![]`.

**Step 4: Build**

```bash
cd tools/off-to-sqlite && cargo build --release
```

**Step 5: Commit**

```
feat: off-to-sqlite — colonne fiber
```

---

### Task 3: Rebuild off_fr.sqlite

**Step 1: Relancer off-reduce**

```bash
cd tools/off-reduce && cargo run --release -- ../../data/openfoodfacts-products.jsonl ../../data/off_fr.jsonl
```

**Step 2: Relancer off-to-sqlite**

```bash
cd tools/off-to-sqlite && cargo run --release -- ../../data/off_fr.jsonl ../../data/off_fr.sqlite
```

**Step 3: Vérifier**

```bash
sqlite3 data/off_fr.sqlite "SELECT code, name, fiber FROM products WHERE fiber IS NOT NULL LIMIT 5;"
```

---

### Task 4: OFFProduct.swift — ajouter fiber

**Files:**
- Modify: `kcalz/Models/OFFProduct.swift`

Ajouter après `let salt: Double?` :
```swift
let fiber: Double?
```

**Commit:**
```
feat: OFFProduct — ajouter fiber
```

---

### Task 5: FoodEntry.swift + UserStore migration

**Files:**
- Modify: `kcalz/Models/FoodEntry.swift`
- Modify: `kcalz/Stores/UserStore.swift`

**Step 1: FoodEntry — ajouter fiberPer100g**

Ajouter après `saltPer100g` :
```swift
let fiberPer100g: Double?
```

Ajouter computed :
```swift
var fiber: Double { (fiberPer100g ?? 0) * grams / 100 }
```

**Step 2: UserStore — migration v9**

```swift
migrator.registerMigration("v9") { db in
    try db.alter(table: "food_entry") { t in
        t.add(column: "fiber_per_100g", .double)
    }
}
```

**Step 3: UserStore — mettre à jour toutes les requêtes**

- `addEntry` : ajouter `fiber_per_100g` dans INSERT
- `copyEntries` : ajouter `fiber_per_100g` dans INSERT de la copie
- `foodEntry(from:)` : lire `row["fiber_per_100g"]`

**Step 4: Build et vérifier**

```bash
xcodebuild ...
```

**Step 5: Commit**

```
feat: FoodEntry + migration v9 — fiber_per_100g
```

---

### Task 6: Meal / DayLog — totalFiber

**Files:**
- Modify: `kcalz/Models/Meal.swift`
- Modify: `kcalz/Models/DayLog.swift`

**Step 1: Meal.swift**

Ajouter :
```swift
var totalFiber: Double { entries.reduce(0) { $0 + $1.fiber } }
```

**Step 2: DayLog.swift**

Ajouter :
```swift
var totalFiber: Double { meals.reduce(0) { $0 + $1.totalFiber } }
```

**Step 3: Commit**

```
feat: Meal/DayLog — totalFiber
```

---

### Task 7: ProductDetailViewModel — fiber

**Files:**
- Modify: `kcalz/ViewModels/ProductDetailViewModel.swift`

**Step 1: Ajouter les propriétés**

```swift
var fiberPer100g: Double?
var fiberText: String  // pour le mode incomplet
```

**Step 2: Init product**

Lire `product.fiber` (ou override).

**Step 3: Init recentEntry / entry**

Lire `entry.fiberPer100g`.

**Step 4: Computed**

```swift
var fiber: Double { scaled(fiberPer100g) }
```

**Step 5: applyOverrideTexts**

```swift
fiberPer100g = Double(fiberText)
```

**Step 6: makeFoodEntry**

Passer `fiberPer100g`.

**Step 7: Commit**

```
feat: ProductDetailViewModel — fiber
```

---

### Task 8: ProductDetailView — ligne fibres

**Files:**
- Modify: `kcalz/Views/Search/ProductDetailView.swift`

Ajouter après la ligne "Sel" dans les deux blocs (read-only et éditable) :

Read-only :
```swift
NutrientDetailRow(label: "Fibres", value: String(format: "%.1f", viewModel.fiber), unit: "g", color: .kcWolf)
```

Éditable :
```swift
EditableNutrientRow(label: "Fibres", unit: "g", text: $viewModel.fiberText, color: .kcWolf)
```

**Commit:**
```
feat: ProductDetailView — ligne fibres
```

---

### Task 9: DashboardView — barre fibres

**Files:**
- Modify: `kcalz/Views/Dashboard/DashboardView.swift`

Dans `macrosBars`, ajouter après la ligne "Sel" :
```swift
("Fibres", dayLog.totalFiber, goal.kcal.map { $0 / 1000 * 15 }, .kcHare),
```

Note : l'objectif fibres est calculé à partir de l'objectif kcal, pas stocké.

**Commit:**
```
feat: Dashboard — barre fibres (objectif 15g/1000 kcal)
```

---

### Task 10: MealDetailView — fibres

**Files:**
- Modify: `kcalz/Views/Meals/MealDetailView.swift`

Ajouter la ligne fibres dans le détail nutriments du repas.

**Commit:**
```
feat: MealDetailView — fibres
```

---

### Task 11: product_override — fiber

**Files:**
- Modify: `kcalz/Stores/UserStore.swift`

Migration v9 (même migration) : ajouter `fiber` à `product_override` aussi :
```swift
try db.alter(table: "product_override") { t in
    t.add(column: "fiber", .double)
}
```

Mettre à jour `ProductOverride` struct, `saveProductOverride`, `loadProductOverride`, `saveCustomFood`, `searchCustomFoods`.

**Commit:**
```
feat: product_override — fiber
```

---

### Task 12: Build final + deploy simulateur

```bash
xcodegen generate
xcodebuild -project kcalz.xcodeproj -scheme kcalz -destination 'platform=iOS Simulator,id=CE97A849' build
xcrun simctl install CE97A849 .../kcalz.app
```

**Commit final :**
```
feat: F24 — fibres (suivi + objectif 15g/1000 kcal)
```
