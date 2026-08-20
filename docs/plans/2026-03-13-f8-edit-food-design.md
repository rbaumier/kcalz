# F8 — Modifier/supprimer un aliment

## Navigation
- `Route.edit(FoodEntry, MealType)` — tap sur une entrée dans MealSectionView
- Réutilise ProductDetailView en mode édition

## ProductDetailView — mode ajout vs édition
- Init avec FoodEntry existant ou OFFProduct
- Mode édition : gramsText pré-rempli, bouton "Modifier", bouton "Supprimer" rouge
- Mode ajout : inchangé
- Callbacks : onSave (renommé onAdd), onDelete optionnel

## UserStore
- updateEntry() — UPDATE grams
- deleteEntry() — déjà implémenté

## DashboardView
- editEntry/removeEntry rechargent le dayLog après mutation

## Swipe-to-delete
- .swipeActions sur les entrées dans MealSectionView
- Callback onDelete
