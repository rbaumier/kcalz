# Features — kcalz

## Done

- **F1** — Scaffold + Dashboard hardcodé (palette Duolingo, ring kcal, barres macros, sections repas)
- **F2** — Script Rust `off-reduce` (réduction dump OFF → JSONL filtré)
- **F3** — Script Rust `off-to-sqlite` (JSONL → SQLite + FTS5, 785k produits, 195Mo)
- **F4** — Recherche OFF (OFFStore GRDB read-only, FTS5 prefix matching, debounce 150ms)
- **F5** — Ajout d'aliment (SearchView → ProductDetailView → ajout au repas, NavigationStack)
- **F6** — Persistance des données utilisateur (GRDB read-write, user.sqlite, auto-save immédiat)

## Next

### Fondations
- **F7** — Navigation entre jours (chevrons fonctionnels, passé et futur, créer un DayLog par date)

### Gestion des aliments
- **F8** — Modifier un aliment (tap sur un aliment du dashboard → même écran que l'ajout, modifier le grammage, bouton supprimer)
- **F9** — Sélection multiple d'aliments (long press → mode sélection, barre d'actions : supprimer ou copier vers un autre repas avec choix date + type de repas via calendrier)
- **F10** — Détail d'un repas (tap sur le titre "Petit déjeuner" → écran avec détails nutriments du repas)

### Recherche avancée
- **F11** — Scan code-barres (recherche OFF par code EAN lors de l'ajout d'un aliment)
- **F12** — Recherche par kcal (taper un nombre de kcal/100g dans la barre de recherche pour filtrer)
- **F13** — Aliments récents / favoris (accès rapide sans recherche)
- **F14** — Aliments custom (créer un aliment non présent dans OFF)

### Objectifs & suivi
- **F15** — Modifier les objectifs (tap sur la zone nutrition du dashboard → écran pour modifier kcal/macros)
- **F16** — Suivi du poids (zone poids sur le dashboard, tap → modifier le poids du jour + graphe d'évolution avec période ajustable)
- **F17** — Onboarding (saisie objectifs, poids initial au premier lancement)

### Stats
- **F18** — Historique & stats (résumé hebdo/mensuel, moyennes, tendances)
