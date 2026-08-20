# Product Overrides — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Garder les produits OFF sans nutriments dans la base, permettre à l'utilisateur de les enrichir manuellement, et protéger ces overrides lors des mises à jour.

**Architecture:** Nouvelle table `product_override` dans `user.sqlite` (migration v6). Le ViewModel accepte les nutriments nil et bascule en mode éditable. Les overrides sont chargés au moment du lookup produit.

**Tech Stack:** Swift 6, SwiftUI, GRDB

---

### Task 1: Migration v6 — table product_override

**Files:**
- Modify: `kcalz/Stores/UserStore.swift:82-88`

**Step 1: Ajouter la migration v6 et les méthodes CRUD**

Après la migration v5 (ligne 86), ajouter :

```swift
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
```

Ajouter les méthodes CRUD dans un nouveau MARK section :

```swift
// MARK: - Product Overrides

struct ProductOverride: Sendable {
    let code: String
    let kcal: Double
    let proteins: Double?
    let carbs: Double?
    let fat: Double?
    let sugars: Double?
    let salt: Double?
}

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
            salt: row["salt"]
        )
    }
}

func saveProductOverride(_ override: ProductOverride) throws {
    try dbQueue.write { db in
        try db.execute(
            sql: """
                INSERT OR REPLACE INTO product_override (code, kcal, proteins, carbs, fat, sugars, salt)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                override.code,
                override.kcal,
                override.proteins,
                override.carbs,
                override.fat,
                override.sugars,
                override.salt,
            ]
        )
    }
}
```

Note: `ProductOverride` peut être déclaré dans `UserStore.swift` directement (pas besoin d'un fichier séparé).

**Step 2: Build pour vérifier la compilation**

Run: `xcodebuild -project kcalz.xcodeproj -scheme kcalz -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "(error:|BUILD)"`
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```
feat: migration v6 — table product_override
```

---

### Task 2: ProductDetailViewModel — mode éditable

**Files:**
- Modify: `kcalz/ViewModels/ProductDetailViewModel.swift`

**Step 1: Rendre les nutriments mutables et ajouter le mode incomplet**

Changer les `let` nutriments en `var` et ajouter les propriétés pour le mode éditable :

```swift
@Observable
@MainActor
final class ProductDetailViewModel {
    let name: String
    let brands: String?
    let productCode: String?
    var kcalPer100g: Double
    var proteinsPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarsPer100g: Double?
    var saltPer100g: Double?
    let existingEntryId: UUID?
    let isIncomplete: Bool

    // Editable text fields for incomplete products
    var kcalText: String
    var proteinsText: String
    var carbsText: String
    var fatText: String
    var sugarsText: String
    var saltText: String

    var gramsText: String

    var isEditing: Bool { existingEntryId != nil }
```

**Step 2: Modifier l'init(product:) pour détecter les produits incomplets**

Ajouter un paramètre optionnel `override`:

```swift
init(product: OFFProduct, override: UserStore.ProductOverride? = nil) {
    self.name = product.name
    self.brands = product.brands
    self.productCode = product.code
    self.existingEntryId = nil

    if let ov = override {
        self.kcalPer100g = ov.kcal
        self.proteinsPer100g = ov.proteins ?? 0
        self.carbsPer100g = ov.carbs ?? 0
        self.fatPer100g = ov.fat ?? 0
        self.sugarsPer100g = ov.sugars
        self.saltPer100g = ov.salt
        self.isIncomplete = false
    } else if product.kcal != nil {
        self.kcalPer100g = product.kcal ?? 0
        self.proteinsPer100g = product.proteins ?? 0
        self.carbsPer100g = product.carbs ?? 0
        self.fatPer100g = product.fat ?? 0
        self.sugarsPer100g = product.sugars
        self.saltPer100g = product.salt
        self.isIncomplete = false
    } else {
        self.kcalPer100g = 0
        self.proteinsPer100g = 0
        self.carbsPer100g = 0
        self.fatPer100g = 0
        self.sugarsPer100g = nil
        self.saltPer100g = nil
        self.isIncomplete = true
    }

    self.kcalText = ""
    self.proteinsText = ""
    self.carbsText = ""
    self.fatText = ""
    self.sugarsText = ""
    self.saltText = ""

    let defaultGrams = Self.parseQuantityGrams(product.quantity) ?? 100
    self.gramsText = defaultGrams.truncatingRemainder(dividingBy: 1) == 0
        ? String(Int(defaultGrams))
        : String(defaultGrams)
}
```

**Step 3: Les autres inits restent inchangés**

Ajouter juste `self.productCode = nil` et `self.isIncomplete = false` et les champs texte vides aux inits `recentEntry` et `entry`.

**Step 4: Modifier isValidInput et makeFoodEntry**

```swift
var isValidInput: Bool {
    guard grams != nil else { return false }
    if isIncomplete {
        return Double(kcalText) != nil
    }
    return true
}

func applyOverrideTexts() {
    if isIncomplete {
        kcalPer100g = Double(kcalText) ?? 0
        proteinsPer100g = Double(proteinsText) ?? 0
        carbsPer100g = Double(carbsText) ?? 0
        fatPer100g = Double(fatText) ?? 0
        sugarsPer100g = Double(sugarsText)
        saltPer100g = Double(saltText)
    }
}
```

**Step 5: Build**

Expected: `** BUILD SUCCEEDED **`

**Step 6: Commit**

```
feat: ProductDetailViewModel — mode éditable pour produits incomplets
```

---

### Task 3: ProductDetailView — bannière + champs éditables

**Files:**
- Modify: `kcalz/Views/Search/ProductDetailView.swift`

**Step 1: Ajouter la bannière et les champs éditables**

Après le header (ligne 40), ajouter la bannière conditionnelle :

```swift
if viewModel.isIncomplete {
    HStack(spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.kcIconMedium)
            .foregroundStyle(Color.kcFox)
        Text("Produit incomplet — renseignez les valeurs nutritionnelles pour 100g")
            .font(.kcCaption)
            .foregroundStyle(Color.kcEel)
    }
    .padding(Theme.cardInnerPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.kcBee.opacity(0.15))
    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM, style: .continuous))
    .padding(.horizontal, Theme.horizontalPadding)
}
```

**Step 2: Remplacer la section Nutrients par un conditionnel**

```swift
if viewModel.isIncomplete {
    // Editable nutrient fields
    VStack(spacing: 0) {
        EditableNutrientRow(label: "Calories", unit: "kcal", text: $viewModel.kcalText, color: .kcFeather, required: true)
        EditableNutrientRow(label: "Protéines", unit: "g", text: $viewModel.proteinsText, color: .kcCardinal)
        EditableNutrientRow(label: "Glucides", unit: "g", text: $viewModel.carbsText, color: .kcMacaw)
        EditableNutrientRow(label: "Lipides", unit: "g", text: $viewModel.fatText, color: .kcBee)
        EditableNutrientRow(label: "Sucres", unit: "g", text: $viewModel.sugarsText, color: .kcFox)
        EditableNutrientRow(label: "Sel", unit: "g", text: $viewModel.saltText, color: .kcHare)
    }
    .kcCard()
    .padding(.horizontal, Theme.horizontalPadding)
} else {
    // Read-only nutrient display (existing code)
    VStack(spacing: 0) { ... }
}
```

**Step 3: Ajouter le composant EditableNutrientRow**

```swift
private struct EditableNutrientRow: View {
    let label: String
    let unit: String
    @Binding var text: String
    let color: Color
    var required: Bool = false

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: Theme.dotSize, height: Theme.dotSize)

            Text(label)
                .font(.kcBody)
                .foregroundStyle(Color.kcEel)

            if required {
                Text("*")
                    .font(.kcBody)
                    .foregroundStyle(Color.kcCardinal)
            }

            Spacer()

            KcNumericField(placeholder: "0", text: $text, font: .kcNumberSmall, width: 70)

            Text(unit)
                .font(.kcCaption)
                .foregroundStyle(Color.kcWolf)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.horizontal, Theme.cardInnerPadding)
        .padding(.vertical, 12)
    }
}
```

**Step 4: Modifier l'init(product:) de ProductDetailView**

Ajouter `userStore` et `onSaveOverride` :

```swift
init(product: OFFProduct, userStore: UserStore, onSave: @escaping (FoodEntry) -> Void) {
    let override = userStore.loadProductOverride(code: product.code)
    _viewModel = State(initialValue: ProductDetailViewModel(product: product, override: override))
    self.onSave = { entry in
        // Save override if product was incomplete
        // (handled in onSave callback from DashboardView)
        onSave(entry)
    }
    self.onDelete = nil
    self._userStore = State(initialValue: userStore)
}
```

Ajouter `@State private var userStore: UserStore?` à la vue.

**Step 5: Modifier le bouton "Ajouter" pour sauvegarder l'override**

```swift
KcPrimaryButton(
    label: viewModel.isEditing ? "Modifier" : "Ajouter",
    enabled: viewModel.isValidInput
) {
    if viewModel.isIncomplete, let code = viewModel.productCode, let userStore {
        viewModel.applyOverrideTexts()
        try? userStore.saveProductOverride(UserStore.ProductOverride(
            code: code,
            kcal: viewModel.kcalPer100g,
            proteins: viewModel.proteinsPer100g,
            carbs: viewModel.carbsPer100g,
            fat: viewModel.fatPer100g,
            sugars: viewModel.sugarsPer100g,
            salt: viewModel.saltPer100g
        ))
    }
    onSave(viewModel.makeFoodEntry())
}
```

**Step 6: Build**

Expected: `** BUILD SUCCEEDED **`

**Step 7: Commit**

```
feat: ProductDetailView — bannière + champs éditables pour produits incomplets
```

---

### Task 4: DashboardView — passer userStore à ProductDetailView

**Files:**
- Modify: `kcalz/Views/Dashboard/DashboardView.swift:64-68`

**Step 1: Mettre à jour les instantiations de ProductDetailView**

Remplacer les 3 cas `.detail`, `.addRecent`, `.edit` pour passer `userStore` au cas `.detail` :

```swift
case .detail(let product, let mealType):
    ProductDetailView(product: product, userStore: userStore, onSave: { entry in
        addEntry(entry, to: mealType)
        path = []
    })
```

Les cas `.addRecent` et `.edit` ne changent pas (les récents/éditions ont déjà leurs nutriments).

**Step 2: Build**

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```
feat: DashboardView — passer userStore pour les overrides produit
```

---

### Task 5: off-reduce — retirer le filtre kcal obligatoire

**Files:**
- Modify: `tools/off-reduce/src/main.rs:59`

**Step 1: Rendre kcal optionnel**

Ligne 59, remplacer :
```rust
let kcal = product.nutriments.energy_kcal_100g?;
```

Par :
```rust
let kcal = product.nutriments.energy_kcal_100g;
```

**Step 2: Adapter write_product pour kcal optionnel**

Changer la signature :
```rust
fn write_product(w: &mut Vec<u8>, code: &str, name: &str, p: &RawProduct, kcal: Option<f64>) {
```

Et dans le corps, rendre kcal conditionnel :
```rust
if let Some(v) = kcal {
    w.extend_from_slice(b",\"kcal\":");
    let mut buf = ryu::Buffer::new();
    w.extend_from_slice(buf.format(v).as_bytes());
}
```

**Step 3: Mettre à jour l'appel**

Ligne 67 :
```rust
write_product(&mut out, code, name, &product, kcal);
```

**Step 4: Build**

Run: `cd tools/off-reduce && cargo build --release`
Expected: compilation OK

**Step 5: Commit**

```
feat: off-reduce — inclure les produits sans nutriments
```

---

### Task 6: Rebuild de la base OFF

**Step 1: Relancer off-reduce**

```bash
cd tools/off-reduce && cargo run --release -- ../../data/openfoodfacts-products.jsonl ../../data/off_fr.jsonl
```

**Step 2: Relancer off-to-sqlite**

```bash
cd tools/off-to-sqlite && cargo run --release -- ../../data/off_fr.jsonl ../../data/off_fr.sqlite
```

**Step 3: Vérifier que le Coca-Cola Zero est présent**

```bash
sqlite3 data/off_fr.sqlite "SELECT code, name, kcal FROM products WHERE code = '5449000214799';"
```

Expected: `5449000214799|Coke ZERO|` (kcal vide/null)

**Step 4: Commit**

```
chore: rebuild off_fr.sqlite avec produits sans nutriments
```
