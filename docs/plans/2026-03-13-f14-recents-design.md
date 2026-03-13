# F14 — Aliments récents / fréquents

## SearchView — état vide (query < 2 chars)

- Toggle pills "Récents" / "Fréquents" (défaut: Récents)
- Liste d'aliments (card blanche, nom + kcal/100g + dernier grammage)
- Tap → ProductDetailView pré-rempli (nutritional data + dernier grammage, id frais)
- Max 20 résultats

## Data

Query `food_entry` existante, pas de nouvelle table.

- **Récents** : derniers aliments ajoutés, dédupliqués par nom, ORDER BY rowid DESC
- **Fréquents** : GROUP BY name, ORDER BY COUNT(*) DESC
- Index sur `name` pour accélérer le GROUP BY

Méthodes UserStore : `recentFoods(limit:)`, `frequentFoods(limit:)`
Retournent des `FoodEntry`.

## Flow

- SearchView reçoit `userStore` en plus de `offStore`
- Tap récent/fréquent → ProductDetailView initialisé avec entry (id frais, grammage pré-rempli)
- Route adaptée pour accepter un FoodEntry en mode "add from recent"
