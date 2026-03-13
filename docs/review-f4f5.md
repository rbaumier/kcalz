# Review F4+F5 — Recherche OFF + Ajout d'aliment

> 10 agents parallèles, chacun a reviewé TOUS les fichiers Swift.
> Résultats agrégés et dédupliqués ci-dessous (45 findings uniques).

---

## P0 — Critiques (à corriger avant la prochaine feature)

### 1. OFFStore bloque le main thread
**Fichier:** `kcalz/Stores/OFFStore.swift`
**Problème:** `@MainActor` force les requêtes SQLite synchrones sur le main thread. De plus `@MainActor + Sendable` est contradictoire — `@MainActor` confine au main thread, `Sendable` déclare thread-safe. Swift 6 strict rejettera ça.
**Fix:** Retirer `@MainActor` et `Sendable` explicite. GRDB `DatabaseQueue` readonly est thread-safe. Rendre `search()` `nonisolated`.

### 2. `fatalError` dans OFFStore.init
**Fichier:** `kcalz/Stores/OFFStore.swift:8`
**Problème:** Crash l'app si le fichier sqlite est absent. Impossible à tester, crash en prod.
**Fix:** `throw OFFStoreError.databaseNotFound` (l'init `throws` déjà).

### 3. Injection FTS5 via les guillemets
**Fichier:** `kcalz/Stores/OFFStore.swift:23`
**Problème:** Les tokens sont wrappés dans `"…"*` sans échapper les `"` de l'input → requête FTS malformée, erreur silencieuse (l'utilisateur voit "aucun résultat").
**Fix:** `token.replacingOccurrences(of: "\"", with: "")` avant de construire la requête.

### 4. `try?` avale l'erreur d'init DB
**Fichier:** `kcalz/App/KcalzApp.swift:15`
**Problème:** `offStore = try? OFFStore()` → écran vide sans explication si la DB ne s'ouvre pas.
**Fix:** `enum AppState { case loading, ready(OFFStore), failed(Error) }` avec UI d'erreur explicite.

---

## P1 — Importants

### 5. Bouton "Ajouter" toujours actif + paste bypass
**Fichier:** `kcalz/Views/Search/ProductDetailView.swift:71`
**Problème:** `grams` retourne `0` si l'input est invalide. `.numberPad` n'empêche pas le paste de texte non-numérique. L'utilisateur peut ajouter un aliment à 0g sans feedback.
**Fix:** Ajouter `var isValidInput: Bool` au ViewModel. `.disabled(!viewModel.isValidInput)` sur le bouton.

### 6. Models sans `Sendable` / `Equatable`
**Fichiers:** `FoodEntry.swift`, `Meal.swift`, `DayLog.swift`
**Problème:** Pas de conformance explicite. SwiftUI ne peut pas diff efficacement sans `Equatable`. Risque de warnings Swift 6 strict.
**Fix:** Ajouter `Sendable, Equatable, Hashable` (structs = gratuit).

### 7. Encapsulation ViewModel cassée
**Fichier:** `kcalz/ViewModels/SearchViewModel.swift`
**Problème:** `results` et `isSearching` sont `var` publiques. `SearchView.swift:34` mute `results` directement depuis la vue, bypass la logique ViewModel.
**Fix:** `private(set) var results`. Exposer `func clearSearch()`.

### 8. Erreurs de recherche silencieuses
**Fichier:** `kcalz/ViewModels/SearchViewModel.swift:37-41`
**Problème:** En cas d'erreur `store.search`, l'erreur est avalée. L'utilisateur voit une liste vide sans explication.
**Fix:** Ajouter `var error: Error?` au ViewModel, l'afficher dans SearchView.

---

## P2 — Améliorations

### 9. DateFormatter recréé à chaque rendu
**Fichier:** `DashboardView.swift:19-24`
**Fix:** `static let` ou cache dans une extension.

### 10. Goal = tuple anonyme
**Fichier:** `PreviewData.swift`
**Fix:** Créer `NutritionGoal` struct (nécessaire pour F15).

### 11. MealType rawValue en français
**Fichier:** `MealType.swift`
**Problème:** `rawValue` = "Petit déjeuner" mélange identifiant technique et label UI.
**Fix:** `rawValue` stable anglais (`breakfast`), computed `displayName` pour l'UI.

### 12. Magic numbers & font sizes incohérentes
**Fichiers:** Toutes les vues
**Problème:** `cornerRadius` (12, 14, 16, 20), `padding` (16, 20), font sizes ad-hoc (`11`, `12`, `13`, `14`, `15`, `28`, `34`) en dehors du design system Theme. Le pattern "label uppercase" (`.font(.system(size: 11, weight: .heavy, design: .rounded))` + kerning) est dupliqué 3 fois.
**Fix:** Centraliser dans Theme : `Font.kcLabel`, `Font.kcIconSmall`, `Font.kcIconLarge`, `Theme.cornerRadius{S,M,L}`, `Theme.horizontalPadding`.

### 13. DashboardView.body trop long + duplication chevrons
**Fichier:** `DashboardView.swift`
**Problème:** ~100 lignes dans body. Les boutons chevron gauche/droite sont du code quasi-identique (seul l'icône change). Body vide `{ }` (pas encore implémenté).
**Fix:** Extraire `DateNavigationButton(direction:action:)`, `NutritionSummaryView`, `MealsListView`.

### 14. Duplication `.reduce` pattern (×8)
**Fichiers:** `Meal.swift:8-11`, `DayLog.swift:9-12`
**Fix:** Extension sur `[FoodEntry]` : `var totalKcal`, `var totalProteins`, etc.

### 15. Duplication calcul `scaled` (×6)
**Fichier:** `ProductDetailViewModel.swift:17-22`
**Fix:** `private func scaled(_ value: Double?) -> Double { (value ?? 0) * grams / 100 }`

### 16. Route enum mal placé
**Fichier:** `DashboardView.swift:3-6`
**Fix:** Extraire dans `Models/Route.swift`.

### 17. `var onAdd` → `let onAdd`
**Fichier:** `MealSectionView.swift:6`
**Fix:** `let onAdd: () -> Void` (jamais muté).

### 18. Types Int/Double incohérents pour goal
**Fichiers:** `KcalRingView.swift:5` (`goal: Int`) vs `NutrientBarView.swift` (`goal: Double`)
**Fix:** Harmoniser sur `Double` partout.

### 19. `Kc3DButton` sans `Sendable`
**Fichier:** `Theme.swift:61-71`
**Fix:** Ajouter `Sendable` (struct avec `Color` et `CGFloat` = trivial).

### 20. `gramsText = "100"` magic string
**Fichier:** `ProductDetailViewModel.swift:7`
**Fix:** `private static let defaultGrams = "100"`.

---

## P3 — Nice to have

### 21. `.onAppear` → `.task`
**Fichiers:** `KcalzApp.swift`, `DashboardView.swift`, `SearchView.swift`
**Fix:** Idiome Swift 6, auto-cancel on disappear.

### 22. Code mort
**Problème:** `kcSmooth` animation helper défini mais jamais utilisé.
**Fix:** Supprimer.

### 23. Accessibilité
**Problème:** Pas de `accessibilityLabel` sur les résultats de recherche, les entrées de repas, le ProgressView. Pas de `accessibilityHint` sur "Ajouter".
**Fix:** Ajouter labels et hints sur tous les éléments interactifs.

### 24. PreviewData vide + Preview crashable
**Problème:** Tous les meals de preview sont vides (pas de test visuel avec données). `#Preview` utilise `try!` qui crash si sqlite absent.
**Fix:** Ajouter `dayLogWithEntries` avec données réalistes. Mock store pour previews.

### 25. `nil` nutritionnel affiché comme `0`
**Problème:** Un produit sans données nutritionnelles (`kcal = nil`) est affiché avec "0 kcal" — l'utilisateur ne sait pas si c'est 0 ou manquant.
**Fix:** Computed `hasNutrients` + indicateur visuel "données manquantes".

### 26. `.numberPad` vs `.decimalPad`
**Fichier:** `ProductDetailView.swift:41`
**Problème:** `.numberPad` ne permet pas les décimales, mais `Double(gramsText)` les accepterait.
**Fix:** Choisir : `.decimalPad` + `Double`, ou `.numberPad` + `Int`.

---

## Recommandation

Corriger **P0 en priorité** avant F6 (persistance). Les P0 #1 et #3 sont des bugs latents (freezes, crashs). Les P0 #2 et #4 empêchent une gestion d'erreur propre nécessaire pour F6.

Les P1 sont rapides à corriger et améliorent la robustesse immédiate.

Les P2 sont de la dette technique acceptable à court terme — certains seront naturellement résolus par les prochaines features (ex: `NutritionGoal` pour F15, `Route` pour F7).
