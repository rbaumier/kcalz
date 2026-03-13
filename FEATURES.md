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

## Next
- **F10** — Détail d'un repas (tap sur le titre "Petit déjeuner" → écran avec détails nutriments du repas)
- **F11** — Poids par défaut pré-remplis quand on ajoute un aliment


### Recherche avancée
- **F12** — Scan code-barres (recherche OFF par code EAN lors de l'ajout d'un aliment)
- **F13** — Recherche par kcal (taper un nombre de kcal/100g dans la barre dcope recherche pour filtrer)
- **F14** — Aliments récents / favoris (accès rapide sans recherche)
- **F15** — Aliments custom (créer un aliment non présent dans OFF)

### Objectifs & suivi
- **F16** — Modifier les objectifs (tap sur la zone nutrition du dashboard → écran pour modifier kcal/macros)
- **F17** — Suivi du poids (zone poids sur le dashboard, tap → modifier le poids du jour + graphe d'évolution avec période ajustable)
- **F18** — Onboarding (saisie objectifs, poids initial au premier lancement)

### Stats
- **F19** — Historique & stats (résumé hebdo/mensuel, moyennes, tendances)
