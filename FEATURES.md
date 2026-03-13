# Features — kcalz

## Done

- **F1** — Scaffold + Dashboard hardcodé (palette Duolingo, ring kcal, barres macros, sections repas)
- **F2** — Script Rust `off-reduce` (réduction dump OFF → JSONL filtré)
- **F3** — Script Rust `off-to-sqlite` (JSONL → SQLite + FTS5, 785k produits, 195Mo)
- **F4** — Recherche OFF (OFFStore GRDB read-only, FTS5 prefix matching, debounce 150ms)
- **F5** — Ajout d'aliment (SearchView → ProductDetailView → ajout au repas, NavigationStack)
- **F6** — Persistance des données utilisateur (GRDB read-write, user.sqlite, auto-save immédiat)
- **F7** — Navigation entre jours (chevrons fonctionnels, passé/futur, "Aujourd'hui")
- **F8** — Modifier un aliment (tap sur un aliment du dashboard → même écran que l'ajout, modifier le grammage, bouton supprimer)
- **F9** — Sélection multiple d'aliments (long press → mode sélection, barre d'actions : supprimer ou copier vers un autre repas)
- **F17** — Suivi du poids (zone poids sur le dashboard, tap → graphe d'évolution avec période ajustable)

- **F14** — Aliments récents / fréquents (historique filtrable, toggle récents/fréquents, brands persistées)

## Next
- **F10** — Détail d'un repas (tap sur le titre "Petit déjeuner" → écran avec détails nutriments du repas)
- **F11** — Poids par défaut pré-remplis quand on ajoute un aliment
- **F12** — Scan code-barres (recherche OFF par code EAN lors de l'ajout d'un aliment)
- **F15** — Aliments custom (créer un aliment non présent dans OFF)
- **F18** — Onboarding (saisie objectifs, poids initial au premier lancement)
- **F19** — Historique & stats (résumé hebdo/mensuel, moyennes, tendances)
