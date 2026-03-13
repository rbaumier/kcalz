# F4+F5 — Recherche OFF + Ajout d'aliment — Plan d'implémentation

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Permettre à l'utilisateur de chercher un aliment dans la base OFF (785k produits) et de l'ajouter à un repas avec une quantité personnalisée.

**Architecture:** 3 écrans en push navigation (Dashboard → SearchView → ProductDetailView). OFFStore ouvre le sqlite read-only via GRDB et expose une recherche FTS5. Les ViewModels sont @Observable. DayLog devient @State dans DashboardView pour permettre l'ajout dynamique.

**Tech Stack:** Swift 6, SwiftUI, GRDB 7, FTS5, @Observable

---

### Task 1: Ajouter off_fr.sqlite au bundle

**Files:**
- Modify: `project.yml`

**Step 1: Ajouter la ressource sqlite dans project.yml**

Ajouter une entrée `resources` dans le target `kcalz` :

```yaml
targets:
  kcalz:
    type: application
    platform: iOS
    sources:
      - path: kcalz
    resources:
      - path: data/off_fr.sqlite
        buildPhase: resources
    settings:
      # ... (inchangé)
```

**Step 2: Regénérer le projet Xcode**

Run: `cd /Users/rbaumier/www/kcalz && xcodegen generate`
Expected: `⚙️  Generating plists... ✅  Project generated`

**Step 3: Vérifier que le fichier est dans le bundle**

Run: `grep -r "off_fr.sqlite" /Users/rbaumier/www/kcalz/kcalz.xcodeproj/project.pbxproj | head -3`
Expected: Le fichier apparaît dans les resources du target

**Step 4: Commit**

```bash
git add project.yml
git commit -m "feat: add off_fr.sqlite to bundle resources"
```

---

### Task 2: Créer OFFProduct — struct miroir de la table products

**Files:**
- Create: `kcalz/Models/OFFProduct.swift`

**Step 1: Écrire le modèle**

```swift
import GRDB

struct OFFProduct: Decodable, FetchableRecord, Identifiable, Sendable {
    var id: String { code }

    let code: String
    let name: String
    let brands: String?
    let categories: String?
    let kcal: Double?
    let proteins: Double?
    let carbs: Double?
    let fat: Double?
    let sugars: Double?
    let salt: Double?
    let nutriscore: String?
    let quantity: String?
    let scans: Int?
}
```

**Step 2: Commit**

```bash
git add kcalz/Models/OFFProduct.swift
git commit -m "feat: add OFFProduct model mirroring products table"
```

---

### Task 3: Créer OFFStore — accès GRDB read-only + recherche FTS5

**Files:**
- Create: `kcalz/Stores/OFFStore.swift`

**Step 1: Écrire OFFStore**

```swift
import GRDB

@MainActor
final class OFFStore {
    private let dbQueue: DatabaseQueue

    init() throws {
        guard let path = Bundle.main.path(forResource: "off_fr", ofType: "sqlite") else {
            fatalError("off_fr.sqlite not found in bundle")
        }
        var config = Configuration()
        config.readonly = true
        dbQueue = try DatabaseQueue(path: path, configuration: config)
    }

    func search(query: String) throws -> [OFFProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        // Escape FTS5 special chars and add prefix matching
        let tokens = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { "\"\($0)\"*" }
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

**Step 2: Commit**

```bash
git add kcalz/Stores/OFFStore.swift
git commit -m "feat: add OFFStore with FTS5 search on OFF database"
```

---

### Task 4: Créer SearchViewModel — @Observable, debounce, résultats

**Files:**
- Create: `kcalz/ViewModels/SearchViewModel.swift`

**Step 1: Écrire le ViewModel**

```swift
import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    var results: [OFFProduct] = []
    var isSearching = false

    private let store: OFFStore
    private var searchTask: Task<Void, Never>?

    init(store: OFFStore) {
        self.store = store
    }

    func onQueryChanged() {
        searchTask?.cancel()

        guard query.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let found = try store.search(query: query)
                if !Task.isCancelled {
                    results = found
                    isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    results = []
                    isSearching = false
                }
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add kcalz/ViewModels/SearchViewModel.swift
git commit -m "feat: add SearchViewModel with debounced FTS5 search"
```

---

### Task 5: Créer ProductDetailViewModel — grammes + calcul nutriments

**Files:**
- Create: `kcalz/ViewModels/ProductDetailViewModel.swift`

**Step 1: Écrire le ViewModel**

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

    var grams: Double {
        Double(gramsText) ?? 0
    }

    var kcal: Double { (product.kcal ?? 0) * grams / 100 }
    var proteins: Double { (product.proteins ?? 0) * grams / 100 }
    var carbs: Double { (product.carbs ?? 0) * grams / 100 }
    var fat: Double { (product.fat ?? 0) * grams / 100 }
    var sugars: Double { (product.sugars ?? 0) * grams / 100 }
    var salt: Double { (product.salt ?? 0) * grams / 100 }

    func makeFoodEntry() -> FoodEntry {
        FoodEntry(
            name: product.name,
            grams: grams,
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

**Step 2: Commit**

```bash
git add kcalz/ViewModels/ProductDetailViewModel.swift
git commit -m "feat: add ProductDetailViewModel with live nutrient calculation"
```

---

### Task 6: Créer SearchView — champ de recherche + liste résultats

**Files:**
- Create: `kcalz/Views/Search/SearchView.swift`

**Step 1: Écrire SearchView**

```swift
import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    let onSelect: (OFFProduct) -> Void

    init(store: OFFStore, onSelect: @escaping (OFFProduct) -> Void) {
        _viewModel = State(initialValue: SearchViewModel(store: store))
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.kcHare)

                TextField("Rechercher un aliment…", text: $viewModel.query)
                    .font(.kcBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: viewModel.query) {
                        viewModel.onQueryChanged()
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                        viewModel.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.kcHare)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.kcSnow)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Results
            if viewModel.query.count < 2 {
                Spacer()
                Text("Tape au moins 2 lettres")
                    .font(.kcBody)
                    .foregroundStyle(Color.kcHare)
                Spacer()
            } else if viewModel.isSearching && viewModel.results.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.results.isEmpty {
                Spacer()
                Text("Aucun résultat")
                    .font(.kcBody)
                    .foregroundStyle(Color.kcHare)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.results) { product in
                            Button { onSelect(product) } label: {
                                SearchResultRow(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Color.kcPolar)
        .navigationTitle("Rechercher")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SearchResultRow: View {
    let product: OFFProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name)
                .font(.kcBody)
                .foregroundStyle(Color.kcEel)
                .lineLimit(1)

            HStack(spacing: 8) {
                if let brands = product.brands, !brands.isEmpty {
                    Text(brands)
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcWolf)
                        .lineLimit(1)
                }

                Spacer()

                if let kcal = product.kcal {
                    Text("\(Int(kcal)) kcal/100g")
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcFeather)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.kcSnow)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.kcPolar)
                .frame(height: 2)
                .padding(.leading, 20)
        }
    }
}
```

**Step 2: Commit**

```bash
git add kcalz/Views/Search/SearchView.swift
git commit -m "feat: add SearchView with search bar and result list"
```

---

### Task 7: Créer ProductDetailView — détail produit + champ grammes + bouton Ajouter

**Files:**
- Create: `kcalz/Views/Search/ProductDetailView.swift`

**Step 1: Écrire ProductDetailView**

```swift
import SwiftUI

struct ProductDetailView: View {
    @State private var viewModel: ProductDetailViewModel
    let onAdd: (FoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    init(product: OFFProduct, onAdd: @escaping (FoodEntry) -> Void) {
        _viewModel = State(initialValue: ProductDetailViewModel(product: product))
        self.onAdd = onAdd
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.product.name)
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcEel)

                    if let brands = viewModel.product.brands, !brands.isEmpty {
                        Text(brands)
                            .font(.kcBody)
                            .foregroundStyle(Color.kcWolf)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Grams input
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUANTITÉ")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.kcWolf)
                        .kerning(0.8)

                    HStack(spacing: 8) {
                        TextField("100", text: $viewModel.gramsText)
                            .font(.kcNumberMedium)
                            .foregroundStyle(Color.kcEel)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(Color.kcSnow)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)

                        Text("grammes")
                            .font(.kcBody)
                            .foregroundStyle(Color.kcWolf)
                    }
                }
                .padding(.horizontal, 20)

                // Nutrients
                VStack(spacing: 0) {
                    NutrientRow(label: "Calories", value: "\(Int(viewModel.kcal))", unit: "kcal", color: .kcFeather)
                    NutrientRow(label: "Protéines", value: String(format: "%.1f", viewModel.proteins), unit: "g", color: .kcCardinal)
                    NutrientRow(label: "Glucides", value: String(format: "%.1f", viewModel.carbs), unit: "g", color: .kcMacaw)
                    NutrientRow(label: "Lipides", value: String(format: "%.1f", viewModel.fat), unit: "g", color: .kcBee)
                    NutrientRow(label: "Sucres", value: String(format: "%.1f", viewModel.sugars), unit: "g", color: .kcFox)
                    NutrientRow(label: "Sel", value: String(format: "%.2f", viewModel.salt), unit: "g", color: .kcHare)
                }
                .background(Color.kcSnow)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
                .padding(.horizontal, 16)

                // Add button
                Button {
                    onAdd(viewModel.makeFoodEntry())
                    dismiss()
                } label: {
                    Text("Ajouter")
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcSnow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.kcFeather)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(Kc3DButton(shadow: .kcWing, depth: 5))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle("Détail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NutrientRow: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.kcBody)
                .foregroundStyle(Color.kcEel)

            Spacer()

            Text(value)
                .font(.kcNumberSmall)
                .foregroundStyle(Color.kcEel)

            Text(unit)
                .font(.kcCaption)
                .foregroundStyle(Color.kcWolf)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
```

**Step 2: Commit**

```bash
git add kcalz/Views/Search/ProductDetailView.swift
git commit -m "feat: add ProductDetailView with grams input and live nutrients"
```

---

### Task 8: Câbler la navigation — NavigationStack + DayLog mutable

**Files:**
- Modify: `kcalz/App/KcalzApp.swift`
- Modify: `kcalz/Views/Dashboard/DashboardView.swift`
- Modify: `kcalz/Views/Components/MealSectionView.swift`

**Step 1: Modifier KcalzApp pour créer OFFStore et le passer en environnement**

```swift
import SwiftUI

@main
struct KcalzApp: App {
    @State private var offStore: OFFStore?

    var body: some Scene {
        WindowGroup {
            if let store = offStore {
                DashboardView(offStore: store)
            } else {
                ProgressView()
                    .onAppear {
                        offStore = try? OFFStore()
                    }
            }
        }
    }
}
```

**Step 2: Modifier DashboardView — @State dayLog + NavigationStack + passer MealType**

Changements clés :
- `let dayLog` → `@State private var dayLog`
- Wraper dans `NavigationStack`
- Passer un callback `addEntry` à MealSectionView
- Navigation vers SearchView puis ProductDetailView

```swift
import SwiftUI

struct DashboardView: View {
    let offStore: OFFStore

    @State private var dayLog = PreviewData.dayLog
    let goal = PreviewData.goal

    @State private var headerAppeared = false
    @State private var summaryAppeared = false
    @State private var selectedMealType: MealType?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: dayLog.date).capitalized
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: - Date navigation
                    HStack {
                        Button { } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.kcWolf)
                                .frame(width: 44, height: 44)
                                .background(Color.kcSnow)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.kcWolf)
                                .frame(width: 44, height: 44)
                                .background(Color.kcSnow)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(Kc3DButton(shadow: Color.kcSwan))
                        .accessibilityLabel("Jour suivant")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                    .opacity(headerAppeared ? 1 : 0)

                    // MARK: - Summary (no card)
                    VStack(spacing: 0) {
                        HStack(spacing: 20) {
                            KcalRingView(consumed: dayLog.totalKcal, goal: goal.kcal)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("CONSOMMÉ")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color.kcWolf)
                                    .kerning(0.8)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(dayLog.totalKcal))")
                                        .font(.kcNumberMedium)
                                        .foregroundStyle(Color.kcFeather)
                                    Text("/ \(goal.kcal) kcal")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Color.kcWolf)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 28)

                        // Macros — compact inline
                        VStack(spacing: 12) {
                            NutrientBarView(label: "Protéines", current: dayLog.totalProteins, goal: goal.proteins, color: .kcCardinal, index: 0)
                            NutrientBarView(label: "Glucides", current: dayLog.totalCarbs, goal: goal.carbs, color: .kcMacaw, index: 1)
                            NutrientBarView(label: "Lipides", current: dayLog.totalFat, goal: goal.fat, color: .kcBee, index: 2)
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                    .opacity(summaryAppeared ? 1 : 0)
                    .offset(y: summaryAppeared ? 0 : 16)

                    // MARK: - Meals
                    VStack(spacing: 24) {
                        ForEach(Array(dayLog.meals.enumerated()), id: \.element.id) { i, meal in
                            MealSectionView(meal: meal, index: i) {
                                selectedMealType = meal.type
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 44)
                }
            }
            .background(Color.kcPolar)
            .navigationDestination(item: $selectedMealType) { mealType in
                SearchView(store: offStore) { product in
                    selectedMealType = nil
                    // This will be handled by ProductDetailView's onAdd
                }
            }
            .onAppear {
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

    private func addEntry(_ entry: FoodEntry, to mealType: MealType) {
        guard let idx = dayLog.meals.firstIndex(where: { $0.type == mealType }) else { return }
        dayLog.meals[idx].entries.append(entry)
    }
}
```

**Note importante:** La navigation SearchView → ProductDetailView et le callback addEntry nécessitent un pattern plus propre. Voici l'approche retenue :

- `DashboardView` utilise `NavigationStack(path:)` avec un enum `Route`
- Le path gère la navigation push/pop proprement

**Step 2b: Approche retenue — NavigationStack avec Route enum**

Ajouter dans DashboardView :

```swift
enum Route: Hashable {
    case search(MealType)
    case detail(OFFProduct, MealType)
}
```

Et faire `OFFProduct` conforme à `Hashable` en ajoutant dans OFFProduct.swift :

```swift
extension OFFProduct: Hashable {
    static func == (lhs: OFFProduct, rhs: OFFProduct) -> Bool {
        lhs.code == rhs.code
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}
```

Le `NavigationStack` final :

```swift
@State private var path: [Route] = []

var body: some View {
    NavigationStack(path: $path) {
        ScrollView {
            // ... même contenu qu'avant
        }
        .background(Color.kcPolar)
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
        .onAppear { /* animations */ }
    }
}
```

**Step 3: Modifier MealSectionView — ajouter callback onAdd**

Changer la signature :

```swift
struct MealSectionView: View {
    let meal: Meal
    let index: Int
    var onAdd: () -> Void

    // ... le reste est identique sauf le bouton "+" :
    Button {
        onAdd()
    } label: {
        // ... identique
    }
}
```

**Step 4: Build et test**

Run: `cd /Users/rbaumier/www/kcalz && xcodegen generate && xcodebuild -project kcalz.xcodeproj -scheme kcalz -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add kcalz/App/KcalzApp.swift kcalz/Views/Dashboard/DashboardView.swift kcalz/Views/Components/MealSectionView.swift kcalz/Models/OFFProduct.swift
git commit -m "feat: wire NavigationStack, mutable DayLog, and search flow"
```

---

### Task 9: Build, deploy sur device, test end-to-end

**Step 1: Build pour device**

```bash
cd /Users/rbaumier/www/kcalz
xcodegen generate
xcodebuild -project kcalz.xcodeproj -scheme kcalz -destination 'generic/platform=iOS' -allowProvisioningUpdates build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 2: Installer sur iPhone**

```bash
xcrun devicectl device install app --device <DEVICE_ID> /Users/rbaumier/Library/Developer/Xcode/DerivedData/kcalz-*/Build/Products/Debug-iphoneos/kcalz.app
```

**Step 3: Tester le flow complet**

1. Dashboard → tap "+" sur un repas → SearchView s'ouvre
2. Taper "nutella" → résultats apparaissent avec debounce
3. Tap sur un résultat → ProductDetailView s'ouvre
4. Changer grammes → nutriments se recalculent live
5. Tap "Ajouter" → retour Dashboard, aliment visible dans le repas

**Step 4: Commit final si corrections**

```bash
git add -A
git commit -m "fix: polish search and add food flow"
```
