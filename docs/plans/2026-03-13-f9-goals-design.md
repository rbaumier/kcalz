# F9 — Goals modifiables

## Accès
Tap sur la zone résumé (ring + barres macros) du dashboard → push GoalsView via NavigationStack.

## Écran GoalsView
6 champs, un par nutriment : kcal, protéines, glucides, lipides, sucre, sel.
Chaque champ est un `TextField` numérique. Vide = désactivé (pas de goal).
Style identique à ProductDetailView (cards blanches, labels UPPERCASE, design tokens Theme).

## Persistance
Nouvelle table `goals` dans UserStore (une seule row, upsert).
Colonnes nullable : `kcal REAL, proteins REAL, carbs REAL, fat REAL, sugars REAL, salt REAL`.

## Dashboard
- Ring kcal : masqué si pas de goal kcal → affiche juste le total consommé en texte
- Barres macros (NutrientBarView) : seules celles avec un goal sont affichées
- Si aucun goal → message "Définir mes objectifs" tappable (même action que tap résumé)

## Modèle
`NutritionGoal` passe à tous les champs optionnels (`kcal: Double?`, `proteins: Double?`, etc.).
