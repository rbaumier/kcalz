# Features — kcalz

## Done

- **F1** — Scaffold + Dashboard hardcodé (palette Duolingo, ring kcal, barres macros, sections repas)
- **F2** — Script Rust `off-reduce` (réduction dump OFF → JSONL filtré, inclut produits sans nutriments)
- **F3** — Script Rust `off-to-sqlite` (JSONL → SQLite + FTS5, 988k produits)
- **F4** — Recherche OFF (OFFStore GRDB read-only, FTS5 prefix matching, debounce 150ms, recherche background)
- **F5** — Ajout d'aliment (SearchView → ProductDetailView → ajout au repas, NavigationStack)
- **F6** — Persistance des données utilisateur (GRDB read-write, user.sqlite, auto-save immédiat)
- **F7** — Navigation entre jours (chevrons fonctionnels, passé/futur, "Aujourd'hui")
- **F8** — Modifier un aliment (tap sur un aliment du dashboard → même écran que l'ajout, modifier le grammage, bouton supprimer)
- **F9** — Sélection multiple d'aliments (long press → mode sélection, barre d'actions : supprimer ou copier vers un autre repas)
- **F10** — Détail d'un repas (tap sur le titre → écran avec détails nutriments du repas)
- **F11** — Copier le repas précédent depuis une section vide
- **F12** — Scan code-barres (recherche OFF par code EAN lors de l'ajout d'un aliment)
- **F13** — Poids par défaut pré-rempli (product_quantity OFF, recherche par code EAN dans le champ texte)
- **F14** — Aliments récents / fréquents (historique filtrable, toggle récents/fréquents, brands persistées)
- **F16** — Enrichissement produits OFF incomplets (overrides utilisateur dans user.sqlite, bannière + champs éditables)
- **F17** — Suivi du poids (zone poids sur le dashboard, tap → graphe d'évolution avec période ajustable)

## Tooling
- **Import MFP v2** — Pipeline mapping interactif (generate-candidates → mapping.html/server.ts → import.ts), 87% mapping, 12% FTS5, 1% brut
- **Match Drive U** — Matching EAN courses U ↔ produits OFF pour enrichir le mapping MFP

- **F15** — Aliments custom (créer un aliment non présent dans OFF, stocké dans product_override, recherchable dans "Mes aliments")

## Next
- **F20** — Retirer le swipe-to-delete sur un aliment (garder uniquement la suppression via tap → détail → supprimer)
- **F21** — Calendrier pour changer de jour (tap sur la date du dashboard → DatePicker)
- **F22** — Lisser la courbe de poids sur les grandes périodes (interpolation/moyenne mobile)
- **F23** — Backup iCloud (copier user.sqlite dans le container iCloud Drive une fois par jour)
- **F24** — Fibres (ajouter le suivi des fibres, objectif 15g pour 1000 kcal)
- **F25** — Checkpoint poids (afficher le diff poids sur le dashboard + pages détail)
