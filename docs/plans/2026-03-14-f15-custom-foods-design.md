# F15 — Aliments custom

## Résumé

Créer un aliment from scratch quand il n'existe pas dans la base OFF. Stocké dans `product_override` avec un code `custom:UUID`.

## Stockage

Migration v7 — ajouter `name` et `brands` à `product_override` :

```sql
ALTER TABLE product_override ADD COLUMN name TEXT;
ALTER TABLE product_override ADD COLUMN brands TEXT;
```

Pour les overrides OFF existants, ces colonnes restent NULL. Pour les custom, code = `custom:UUID`.

## Accès

Bouton "Créer cet aliment" dans SearchView quand "Aucun résultat" s'affiche. Pré-remplit le nom avec la query.

## Flow

1. SearchView → "Aucun résultat" → "Créer cet aliment"
2. CreateFoodView — nom (pré-rempli, obligatoire), kcal/100g (obligatoire), protéines/glucides/lipides (optionnels)
3. "Créer" sauvegarde dans `product_override` avec code `custom:UUID`
4. Push ProductDetailView → grammage → "Ajouter"

## Recherche

`searchCustomFoods(query:)` — LIKE sur `name` dans `product_override` WHERE code LIKE 'custom:%'. Section "Mes aliments" en haut de SearchView.

## Fichiers impactés

- `UserStore.swift` — migration v7, `saveCustomFood()`, `searchCustomFoods(query:)`
- `Views/Search/CreateFoodView.swift` — nouveau formulaire
- `Views/Search/SearchView.swift` — bouton + section "Mes aliments"
- `Models/Route.swift` — `case createFood(String, MealType)`
- `DashboardView.swift` — navigation `.createFood`
